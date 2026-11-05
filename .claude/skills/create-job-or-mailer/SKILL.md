---
name: create-job-or-mailer
description: Add a Sidekiq background job (app/jobs) or an ActionMailer mailer (app/mailers) with its template and spec, safe to retry and enqueued after commit. Use whenever the user wants something to run in the background, on a schedule, or by email, such as "send a welcome email", "notify admins when X", "nightly cleanup" or "process this async", even if they never say "job" or "mailer". Not for Devise's own emails (edit app/views/devise/mailer directly), and not the whole feature around it (implement-feature sequences that).
---

Job or mailer: $ARGUMENTS

If this is one piece of a larger feature, use `implement-feature`. Devise's confirmation and
reset templates live in `app/views/devise/mailer/*.slim`; edit those for copy changes.

`.claude/rules/jobs-and-mailers.md` loads when you open these files and holds the full rules.
This is the sequence.

## 1. Decide what it is, and who triggers it

- **Mailer**: composes one email. Called as `UserMailer.welcome(user).deliver_later`. No mailer
  exists beyond the base class yet, so you are setting the pattern.
- **Job**: runs work off the request. `app/jobs/devise_jwt/purge_expired_jwts_job.rb` is the
  worked example. A mailer's `deliver_later` is already a job, so do not write a job whose only
  body is `deliver_now`.
- **Recurring**: add it to `config/schedule.yml`, and decide the queue deliberately. The two
  existing entries declare `default` while their jobs declare `low`.

Whoever triggers it is an **operation**, not a model or callback: the architecture spec fails on
`deliver_later` or `perform_later` in `app/models`.

## 2. Before writing

- Which queue: `critical`, `default` or `low`? Anything else is never processed.
- What happens when it runs twice? Sidekiq retries a failed job, so a repeat must be a no-op or
  converge. No uniqueness gem is installed, so idempotency is on you.
- Does it get ids or records? Use ids if the row can change or disappear before dequeue.
- Is it enqueued inside a transaction? Move it after the block.
  See `.claude/rules/rails-transactions.md`.

## 3. Spec

Put specs in `spec/jobs/` and `spec/mailers/`, starting with `require 'rails_helper'`. The `:test`
adapter is active, so use the shared example, then assert the effect:

```ruby
describe Reports::GenerateJob do
  include_examples 'enqueues_job_correctly', :low

  describe '#perform' do
    # run it, assert the effect; run it twice if it is not obviously idempotent
  end
end
```

For a mailer, check `subject`, `to` and `body`.

## 4. Verify

Yours to run and paste:

- `bundle exec rspec spec/jobs spec/mailers spec/architecture_spec.rb`
- `bundle exec rubocop app/jobs app/mailers spec/jobs spec/mailers`
- `bin/rails zeitwerk:check`

Preview a mailer in development through letter_opener, or say plainly that you could not check
it. Report the files added, how retries and enqueue timing are handled, and the commands you ran.
