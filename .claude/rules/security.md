---
paths:
  - "app/policies/**/*.rb"
  - "app/controllers/api/v1/auth/**/*.rb"
  - "app/controllers/api/v1/base_controller.rb"
  - "config/environments/*.rb"
  - "config/application.rb"
  - "config/initializers/**/*.rb"
  - "config/routes.rb"
---

# Authorization, authentication and configuration

## Authorization

- Pundit is the authorization layer, and **nothing enforces it**. `ApplicationPolicy`
  denies by default, but only for actions that call `authorize`.
- A policy file is at `app/policies/<model>_policy.rb`. A namespaced model has a
  namespaced policy, as `ActiveStorage::BlobPolicy` does.
- Scope collections with `policy_scope`. `ApplicationPolicy::Scope#resolve` raises until
  a subclass defines it.
- Authorize the record you fetched, not just the class, or any user can reach any id:
  `authorize(Product.find(params[:id]))`.
- Every policy gets a spec. Use `pundit-matchers`, and cover the denied case.

## Authentication

- devise-jwt with the Allowlist strategy: tokens live in `allowlisted_jwts`. A new
  sign-in or sign-out path must be added to `jwt.dispatch_requests` or
  `jwt.revocation_requests` in `config/initializers/devise.rb`.
- Users are `:confirmable`. `config.paranoid = true` is on, so password and confirmation
  responses must not reveal whether an email exists.
- `jwt.secret` reads `JWT_SECRET_KEY`. The value in `.env.sample` is public, so every
  real environment needs its own.

## Exposure

Check these when touching routes or initializers:

- **Sidekiq Web** is mounted at `/sidekiq` unconditionally, and
  `config/initializers/sidekiq_web.rb` adds basic auth only when both
  `SIDEKIQ_WEB_USERNAME` and `SIDEKIQ_WEB_PASSWORD` are set. If either is missing, the
  dashboard is public. Any new operational mount needs a gate that fails closed.
- **API docs** mount at `/docs` when `APP_DOCUMENT` is set, and `.env.sample` sets it.
  Do not carry that into production unintentionally.
- **CORS** in `config/initializers/cors.rb` allows `origins '*'`. Narrow it for a real
  deployment rather than widening anything else around it. `Authorization` must stay in
  `expose`, or clients cannot read the token.
- **Blobs**: `GET /blobs/:signed_id` redirects to the file without authentication, so a
  signed id is effectively a public link. Do not store private documents this way
  without changing that.
- **Uploads**: `Blobs::Create` checks `file.content_type`, which the client declares.
  Do not treat it as proof of the content. Limits live in `Constants`.
- **Sentry** in `config/initializers/sentry.rb` traces every request (`traces_sampler`
  always returns `true`). Do not copy that shape; sample deliberately.

## Secrets

Never read, write or print `.env`, `config/master.key`, `config/credentials/*.key`, or
any `*.pem` / `*.key`. The hooks in `.claude/hooks` block this; do not work around them.
`.env.sample` is the file to update when a new variable is introduced. Also add new
sensitive parameter names to `config/initializers/filter_parameter_logging.rb`.
