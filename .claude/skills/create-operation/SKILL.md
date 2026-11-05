---
name: create-operation
description: Add an Operation (app/operations) for a business workflow with several writes, several collaborators, or a sequence someone has to be able to read, returning its value and raising APIError on failure, with a spec. Use whenever the user wants a service object, a use case, "a class that does X then Y", or logic is outgrowing a controller action or a model callback. Not for a single Model.create or update (that stays on the model), not for reads (a query object), and not when the operation is one layer of a larger feature (implement-feature sequences that).
---

Operation: $ARGUMENTS

If this is one piece of a feature you are also building, use `implement-feature`. If the
work is a read, it is a query object: use `create-query`. This repo has no `app/services`;
do not create one.

## 1. Check it earns an operation

An operation is a *workflow*. Line count is not the test: a long method about one record's
own state belongs on the model, and a short method coordinating three objects belongs here.
An operation that only wraps `Model.create(...)` is noise; say so and stop.

Read `app/operations/blobs/create.rb` and the sample at the top of
`application_operation.rb`.

## 2. Shape

- Namespace by resource, name with a verb: `Users::Approve`, never `Users::Approver`. File
  at `app/operations/users/approve.rb`. Subclass `ApplicationOperation`;
  `spec/architecture_spec.rb` fails otherwise.
- Collaborators come through `initialize` with defaults, so a spec can inject a double. The
  work is the instance method `#call`.
- Call it as `Users::Approve.call(user)`.
- Return the value the caller renders. There is no result object.
- Fail by raising: `APIError::*` for what the client should see, a bang method for records.
  Check the constructor first, because they differ. See
  `.claude/rules/serializers-and-errors.md`.

```ruby
module Users
  class Approve < ApplicationOperation
    def initialize(notifier = UserMailer)
      @notifier = notifier
    end

    def call(user)
      raise APIError::BadRequestError.new(message: 'Already approved') if user.approved?

      user.update!(approved_at: Time.current)
      notifier.approved(user).deliver_later
      user
    end

    private

    attr_reader :notifier
  end
end
```

## 3. The decisions that go wrong

- **Transaction.** Open one only if several writes must land together, and keep it to the
  writes. One `save!` is already transactional.
- **Mail and jobs.** Do them *after* the block. A job enqueued inside can start before its
  row is visible, and this was measured here. See `.claude/rules/rails-transactions.md`.
- **Rescue narrowly.** A blanket rescue turns a bug into a quiet failure, and the
  architecture spec fails on one. Do not rescue `RecordInvalid` to re-render it:
  `ExceptionFilter` already does.
- **Authorization** stays in the controller.

## 4. Spec

`spec/operations/users/approve_spec.rb`, starting with `require 'rails_helper'`. Cover the
returned value, each raised error, and, for a multi-write operation, that nothing persisted
when the second write fails. A spec that still passes if the operation were deleted proves
nothing.

## 5. Verify

Yours to run and paste:

- `bundle exec rspec spec/operations spec/architecture_spec.rb`
- `bundle exec rubocop app/operations spec/operations`
- `bin/rails zeitwerk:check`

Report the files added, the transaction and rescue decisions and why, and the commands you
ran.
