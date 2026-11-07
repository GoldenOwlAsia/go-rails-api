---
name: upgrade-dependencies
description: Bump gems in this boilerplate and prove the result still boots, lints and passes, covering the runtime pins that must move together and the silent breakage specs here do not catch. Use when updating dependencies, refreshing the lockfile, or acting on a security advisory. Not for a Rails major-version upgrade.
---

Upgrade: $ARGUMENTS

This is not a Rails major-version upgrade. That is a different job, with `app:update`, and this
skill does not cover it.

## 1. Establish what is out of date

```sh
bundle outdated --strict --parseable
```

`bundler-audit` is not installed; for advisories, ask the user or use a source they name. Do not add
it to the Gemfile unasked. Split the result before touching the lockfile, and say which bucket each
change is in:

- **security**: goes first, on its own
- **patch and minor**: routine, batch these
- **major**: one at a time, each with its changelog read, never batched

## 2. Bump

Prefer the narrow command. `bundle update` with no argument turns a two-line diff into an unreviewable
one.

```sh
bundle update <gem> --conservative
```

## 3. Runtime pins move together or not at all

A Ruby change must update `.ruby-version`, `Gemfile`, `Dockerfile` (`ARG RUBY_VERSION`), `README.md`
and `.rubocop.yml` (`TargetRubyVersion`), or the image builds on a different interpreter than every
test ran on. `repo-consistency-audit` is the maintained copy of that list, so run it after a runtime bump.

## 4. Read what a major actually changed

Read the changelog, not the version number. A green suite proves little here, because the specs only
reach what an endpoint exercises:

- **pagy** is the proof. The 9.x rename of `items` to `limit` left `Pagy::DEFAULT[:items]` and
  `paginate` silently wrong, and the first paginated response returns 500, with a green suite the whole
  time. See `.claude/rules/controllers.md`.
- **Devise, devise-jwt and Pundit** sit under authentication and authorization. A major in any of them
  means re-running the auth and policy specs deliberately, and dispatching `reviewer-agent`.
- **blueprinter and oj** define every response body. Check the request specs' `schema` blocks really
  have `required:` before trusting them.
- **rswag** regenerates the docs. A bump can churn `swagger/v1/swagger.yaml`, so review that diff.
- **sidekiq and sidekiq-cron**: `config/schedule.yml` and `config/sidekiq.yml` are never loaded by a
  spec, so boot a worker or say you did not.

## 5. Verify the whole thing

The Stop hook covers changed files only, and a bump can break a file nobody edited. Run the full gate and
paste real output:

```sh
bundle exec rspec -r rails_helper
bundle exec rubocop
bundle exec brakeman --no-pager
bin/rails zeitwerk:check
bin/rails runner 'Rails.application.eager_load!'
.claude/hooks/test-guards.sh
```

Never weaken a spec, a lint rule or a `.rubocop.yml` exclusion to absorb an upgrade. If a bump requires a
code change, that change is part of the work; if it requires deleting a check, stop and report it.

## 6. Report

Which gems moved and to what, which bucket each was in, what the changelogs said for any major, every
command you ran with its result, and anything you held back and why.
