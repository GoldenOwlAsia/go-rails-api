---
paths:
  - "app/operations/**/*.rb"
  - "app/queries/**/*.rb"
---

# Operations and queries

## Operations (`app/operations`)

- Subclass `ApplicationOperation`. Define `#call` as an instance method; `.call(...)`
  builds an instance and forwards to it.
- Collaborators come through `initialize` with defaults, exposed by a private
  `attr_reader`, as in the sample at the top of `application_operation.rb`.
- **There is no result object.** Return the value the caller needs, and signal failure
  by raising: `APIError::*` for what the client should see, a bang method for records.
  `ExceptionFilter` renders both. `Blobs::Create` is the worked example. Do not invent
  `success` / `failure` wrappers.
- Wrap multi-write workflows in `ActiveRecord::Base.transaction`. See
  `.claude/rules/rails-transactions.md`.
- Rescue narrowly. Catch the error you have a plan for and let the rest surface.
  `spec/architecture_spec.rb` fails on a blanket rescue anywhere in `app/`.
- Authorization stays in the controller.
- Do not move plain model persistence into an operation just to have one.

## Queries (`app/queries`)

- Subclass `ApplicationQuery`. Define `#call(scope = Model.all, **params)`.
- Use `filter(scope, :method_name, value)`, which skips blank values, and
  `sort(scope, value)`, which understands `+column` and `-column`.
- Filter methods are private, take `(scope, value)` and return a relation. The blank
  check is already done, so the body is just `scope.where(...)`.
- Return an `ActiveRecord::Relation` so callers can compose and paginate. Never mutate
  records from a query.
- Read a key with the name the caller passes. The sample in `application_query.rb`
  reads `params[:term]` while its usage lines pass `name:`, so that filter never runs.
  Do not copy the mismatch.
- **Allowlist any sort column from user input.** `sort` passes the value to
  `order(column => direction)`. Measured on Rails 8.0.2: an unknown column such as
  `?sort=whatever` raises `ActiveRecord::StatementInvalid`, and an SQL-shaped value
  raises `ActiveRecord::UnknownAttributeReference`. Neither is an injection, and
  neither is mapped by `ExceptionFilter`, so both return 500.
- Never interpolate user input into SQL. Use placeholders, and `sanitize_sql_like`
  when `%` and `_` should match literally.
- Primary keys are random UUIDs, so an unordered page is arbitrary. Order explicitly,
  with `:id` as a tiebreaker.
- Choose `includes`, `preload` or `joins` from how the result is consumed. Bullet runs
  in development and flags real N+1s.

### Calling a query from a controller

Do not splat `params`. `**params` raises `ActionController::UnfilteredParameters`
(a 500). `**params.permit(...)` gets through, but with string keys, so `params[:term]`
reads `nil` and every filter is silently skipped. Permit the list and symbolize it:

```ruby
def index
  authorize(Product)
  products = Products::GeneralQuery.call(policy_scope(Product), **query_params)
  render_resource_collection(products, each_serializer: ProductSerializer)
end

private

def query_params
  params.permit(:term, :sort).to_h.symbolize_keys
end
```

Passing the policy scope first means filters run only over what the user may see.
