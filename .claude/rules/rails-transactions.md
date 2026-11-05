---
paths:
  - "app/operations/**/*.rb"
  - "app/models/**/*.rb"
  - "app/jobs/**/*.rb"
  - "app/controllers/**/*.rb"
---

# Transactions

The measurements below were taken against this app on Rails 8.0.2.

## Use one when several writes must commit as a unit

```ruby
ActiveRecord::Base.transaction do
  order = Order.create!(...)
  user.update!(balance: user.balance - product.price)
  order
end
```

Use bang methods inside. A non-bang `save` returning `false` does not roll anything
back.

## Do not wrap a single ordinary save

`save` and `destroy` already run in their own transaction, together with their
validations and callbacks. An outer transaction around one `create!` adds nothing.

## Keep non-database work out of the block

No HTTP calls, no mail delivery, no file uploads, no slow computation. They hold locks
open and cannot be rolled back. `Blobs::Create` uploads with no transaction open.

Enqueuing is the trap. `enqueue_after_transaction_commit` defaults to `false`, and a job
enqueued inside the block was handed to the queue adapter **before** the commit
(measured with a recording adapter). With Sidekiq, a worker can pick it up in that
window and fail to find the row, or act on a record that gets rolled back.

Either enqueue after the block, which is the simplest, or set this on the job class.
Measured: the job then reaches the adapter only after the commit.

```ruby
class OrderConfirmationJob < ApplicationJob
  self.enqueue_after_transaction_commit = true
end
```

Use `true` or `false`. The symbols `:always`, `:never` and `:default` are deprecated in
Rails 8.0 and removed in 8.1.

## Nested transactions are not nested by default

```ruby
ActiveRecord::Base.transaction do
  User.create!(...)                       # outer
  ActiveRecord::Base.transaction do
    User.create!(...)                     # joins the SAME transaction
    raise ActiveRecord::Rollback          # silently discarded
  end
end
```

Measured: `BEGIN`, `COMMIT`, and **both** users persist. Ask for a real sub-transaction
explicitly with `transaction(requires_new: true)`. Measured: `BEGIN`, `SAVEPOINT`,
`ROLLBACK TO`, `COMMIT`, and only the outer user persists.

If you nest at all, know which of these you meant. Prefer not nesting.

## Operations

`ApplicationOperation` does not open a transaction for you. Open one in `#call` when the
workflow needs it, and keep it to the writes. Let `RecordInvalid` propagate:
`ExceptionFilter` renders it as a 422 after the rollback.
