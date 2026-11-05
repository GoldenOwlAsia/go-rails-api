# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Golden Owl's Rails API boilerplate: Ruby 3.4.1, Rails 8.0 (API-only), PostgreSQL, Sidekiq/Redis, Devise + JWT, Pundit, Blueprinter, rswag, RSpec.

## Commands

```bash
# Setup: first create config/database.yml (from config/database.yml.sample) and .env (from .env.sample); both are gitignored
bin/setup --skip-server

bin/rails s                 # API server
bundle exec sidekiq         # background jobs and cron (needs Redis)

bundle exec rspec                                   # full suite; coverage report at coverage/index.html
bundle exec rspec spec/requests/api/v1/blobs_request_spec.rb:12   # single file or example
bundle exec rspec -r rails_helper spec/models/user_spec.rb        # see the note below

bundle exec rubocop         # lint
bundle exec brakeman        # security scan
bin/rake rswag              # regenerate swagger/v1/swagger.yaml from request specs
```

`.rspec` only loads `spec_helper`. Specs that don't require a helper themselves (`spec/models`, `spec/policies`, `spec/operations`) need `-r rails_helper` when run on their own. New specs should start with `require 'rails_helper'`, or `require 'swagger_helper'` for request specs.

## Architecture

Requests flow: route → controller (auth, `authorize`, strong params) → operation or query → serializer via `render_resource`. Exceptions are turned into JSON by `ExceptionFilter`.

### Layers beyond standard Rails

- **Operations** (`app/operations/<namespace>/<verb>.rb`, `ApplicationOperation`): business logic with a single public `call`. Collaborators are injected through `initialize` with defaults. Invoke with `Users::Approve.call(...)`. This project uses operations, not "services".
- **Queries** (`app/queries`, `ApplicationQuery`): composable read logic. `call(scope = Model.all, **params)` chains the `filter(scope, :method, value)` helper, which skips blank values, and `sort(scope, '-column')`.
- **Serializers** (`app/serializers`, Blueprinter via Oj): `render_resource` and `render_resource_collection` find `"#{Model}Serializer"` by name. Pass `serializer:` / `each_serializer:` otherwise, which is required for arrays and for namespaced models such as `ActiveStorage::Blob`. Other options (`view:`, `meta:`) go to the serializer; `status:` and `pagy:` go to the render.
- **Errors** (`app/errors/api_error`): raise an `APIError::*` subclass from anywhere in a request and `ExceptionFilter` renders it. It also maps `Pundit::NotAuthorizedError`, `ParameterMissing`, `RecordNotFound`, and `RecordInvalid`/`RecordNotDestroyed`, so prefer bang methods over hand-written error handling.
- **Decorators** (`app/decorators`, `ApplicationDecorator`): `SimpleDelegator` wrappers; `wrap_all` wraps a collection.
- **Overrides** (`app/overrides/**/*_override.rb`): ignored by Zeitwerk and `load`ed in `to_prepare`. Use them to reopen gem classes.

### Controller conventions

- API controllers inherit from `API::V1::BaseController`, which enforces `authenticate_user!`. Auth controllers that need Devise behaviour inherit from `Devise::*Controller` instead and override `respond_with`.
- Pundit authorization is **not** enforced automatically: nothing calls `verify_authorized`, so each action must call `authorize`. `ApplicationPolicy` denies everything by default.
- Pagination: `pagy, records = paginate(scope)`, then `render_resource_collection(records, pagy:)`. Clients send `page[number]` and `page[size]`. Collections render as `{ data: [...], meta: {...} }`. **This is broken on the installed pagy 9.3.4 and raises on the first paginated response**; `.claude/rules/controllers.md` has the fix.

### Naming

`API` and `JSONAPI` are registered acronyms (`config/initializers/inflections.rb`), so Zeitwerk expects `API::V1`, `JSONAPIRender`, and so on. `APIError` follows from the `API` acronym, with files under `app/errors/api_error/`. The namespace is not `Api`.

### Auth

devise-jwt uses the **Allowlist** revocation strategy: tokens live in `allowlisted_jwts`. A token is issued only by `POST /api/v1/auth/sign_in` (in the `Authorization` response header) and revoked by `DELETE /api/v1/auth/sign_out`. New sign-in or sign-out paths must also be added to `jwt.dispatch_requests` / `jwt.revocation_requests` in `config/initializers/devise.rb`. Users are `:confirmable`; the `:user` factory is confirmed by default, and the `:need_confirmation` trait is not.

### File uploads

Uploads take two steps. `POST /api/v1/blobs` creates a blob and returns its `signed_id`, which the client then sends as the attachment param (e.g. `user[avatar]`). Unattached blobs older than a day are purged nightly.

Active Storage's default routes are disabled (`draw_routes = false`). `config/routes.rb` defines `blobs/:signed_id` and the disk service route by hand. Allowed types and size limits are in `config/initializers/constants.rb`. Storage services: `local` in development, `test` in test, `amazon` in production.

### Background jobs

Active Job uses Sidekiq, with queues `critical`, `default`, and `low`. Recurring jobs are declared in `config/schedule.yml` (sidekiq-cron). The test environment uses the `:test` queue adapter.

## Testing and API docs

Request specs in `spec/requests` double as the API documentation: they use the rswag DSL (`path` / `response` / `schema` / `run_test!`), with auth via `let(:Authorization) { auth_header(user) }`. Helpers (`json_response`, `auth_header`) and shared examples are in `spec/supports`. After changing an API, update its request spec and run `bin/rake rswag`; `swagger/v1/swagger.yaml` is committed. The docs UI is mounted at `/docs` only when `APP_DOCUMENT` is set.

## Migrations

Generators default to UUID primary keys. In development, migrating re-annotates the schema comments at the top of model files through annotaterb, so expect those files in the diff.

## How Claude works here

Layer conventions live in `.claude/rules/` and load when you open a matching file; `rails-architecture.md` always loads and has the table for choosing a layer. These boundaries are enforced by `spec/architecture_spec.rb`, not just described. If an example blocks work you believe is right, change the rule and the example together and say so.

`.claude/skills/` holds the workflows: `implement-feature` for multi-layer work; `create-endpoint`, `create-migration`, `create-operation`, `create-query` and `create-job-or-mailer` for one layer; `api-contract-audit` and `repo-consistency-audit` as read-only audits; `upgrade-dependencies` for maintenance. A new skill must state what it is *not* for, so the choice between skills stays clear.

The two agents in `.claude/agents/` are both read-only and exist for context isolation: `reviewer-agent` (fresh eyes on finished work or a plan) and `bug-investigator` (root-cause tracing across many files). Write the code yourself. There are deliberately no write-capable agents.

### Workflow

Before editing, find an existing analogous implementation and follow it, trace the full data flow, and fix the root cause rather than the symptom.

After editing, run what the change touched and say which commands you ran. Never claim something passes without having run it and seen the output.

- `bundle exec rspec <paths>`: targeted specs first
- `bundle exec rubocop <files>`
- `bin/rails zeitwerk:check`: when files or constants were added, moved or renamed
- `bin/rake rswag`: when an API changed
- `bundle exec brakeman --no-pager`: when auth, params, queries or uploads changed
- `.claude/hooks/test-guards.sh`: when a hook changed

There is no CI, so nothing else runs these for you.

### Safety

- Never read or write `.env`, `config/master.key`, `config/credentials/*.key`, or any `*.pem` / `*.key`. Update `.env.sample` for a new variable and tell the user what to set.
- Never run destructive database tasks (`db:drop`, `db:reset`, `db:schema:load`, and similar) outside `RAILS_ENV=test`, and never target production.
- Do not add a gem without a concrete requirement in the task.
- Do not change public behaviour while refactoring. `/api/v1` response shapes are a contract with clients.

`.claude/hooks/` enforces most of this. The hooks stop mistakes rather than being a security boundary, so do not look for a way around them.

### Git

- `git commit` and `git push` are blocked by a hook and are the user's to run. Describe what changed and let them commit.
- Commands that discard uncommitted work are blocked too: `reset --hard`, `clean -f`, `checkout -- <path>`, `restore <path>`. Stash instead, or ask.
- Keep unrelated changes out of the diff.
- Never edit a migration that has been committed. Append a new one.

### Compaction

When compacting, preserve the root cause found, files modified, decisions taken, unresolved issues, and which verification commands were actually run with their results. Path-scoped rules are not re-injected after a compaction; they reload when you next read a matching file.
