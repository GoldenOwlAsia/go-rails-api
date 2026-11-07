---
paths:
  - "app/jobs/**/*.rb"
  - "app/mailers/**/*.rb"
  - "app/views/**/*.slim"
  - "app/views/**/*.erb"
  - "config/schedule.yml"
  - "config/sidekiq.yml"
---

# Background jobs and mailers

## Jobs

Active Job on Sidekiq, in development and production. `config/sidekiq.yml` declares the
`critical`, `default` and `low` queues; a queue not listed there is never processed.
Set one with `queue_as`.

- Take ids, not records, as arguments when the row may change or disappear before
  dequeue, and re-fetch inside `#perform`.
- Jobs must be safe to run twice, because a failed job is retried. A repeat run must be
  a no-op or converge to the same state.
- Do not rescue broadly. It hides the failure from Sidekiq's retry and from Sentry.
  Use `discard_on ActiveRecord::RecordNotFound` when a record is legitimately gone.
  `spec/architecture_spec.rb` fails on a blanket rescue.
- Enqueue after commit. See `.claude/rules/rails-transactions.md`.
- No uniqueness gem is installed. If a job must not run concurrently for one resource,
  design for it (a row lock, an idempotent write) and do not assume a lock exists.
- A recurring job goes in `config/schedule.yml` (sidekiq-cron), not in a `loop` or
  `sleep`. It runs only under `bundle exec sidekiq`. The `queue:` there and the job's
  `queue_as` should agree: the two existing entries say `default` while their jobs say
  `low`, so check which one you mean.

### Testing

The test environment uses the `:test` adapter, so `have_enqueued_job` works and nothing
touches Redis. Use the shared example in `spec/supports/shared_examples`:

```ruby
include_examples 'enqueues_job_correctly', :low
```

Add a spec that runs `#perform` and asserts the effect, and for anything not obviously
idempotent, run it twice and assert the result is the same.

## Mailers

`ApplicationMailer` sets `layout 'mailer'` and reads `from` from `MAILER_FROM_EMAIL`.
Do not override `from` unless the sender genuinely differs.

- Delivery is `letter_opener` in development, `smtp` in production, `:test` in test.
- Call `.deliver_later` from an operation, after any transaction.
- Build links with `_url` helpers. The host comes from `APP_HOST`.
- Mail templates are the only views in this app: Slim under `app/views/<mailer>/`, with
  inline styles or tables. No asset pipeline stands behind them.
- Devise's templates are already copied to `app/views/devise/mailer`. Edit those for
  copy changes rather than adding a mailer. Devise sends them synchronously, because
  `User` does not override `send_devise_notification`.
- In a spec, assert on `ActionMailer::Base.deliveries`, or call the mailer method and
  check `subject`, `to` and `body`.
