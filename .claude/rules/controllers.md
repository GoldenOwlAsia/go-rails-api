---
paths:
  - "app/controllers/**/*.rb"
  - "config/routes.rb"
---

# Controllers

`ApplicationController` already includes `Pundit::Authorization`, `Pagy::Backend`,
`JSONAPIRender` and `ExceptionFilter`. `API::V1::BaseController` adds
`authenticate_user!`. Do not re-add those.

- Orchestrate only: authorize, delegate the mutation to an operation and the read
  to a query, then render.
- New API controllers inherit `API::V1::BaseController`, under `module API` /
  `module V1`. The namespace is `API`, not `Api`. Auth endpoints that need Devise
  behaviour inherit `Devise::*Controller` and override `respond_with`.
- **Nothing enforces Pundit.** No `verify_authorized` runs, so an action without
  `authorize` is open to every signed-in user and fails silently. Call `authorize`
  in every action, and pass collections through `policy_scope`.
  `spec/architecture_spec.rb` fails on a controller with no authorization at all;
  a single action that forgets it is still on you.
- Strong parameters are a private `<resource>_params` method using
  `params.require(:x).permit(...)`.
- Do not use `filter_params` or `order_params` from `ApplicationController`.
  `params[:filter].permit!` raises `NoMethodError` when the param is absent (a 500),
  and permits every key when it is present.
- Do not rescue here. `ExceptionFilter` maps `Pundit::NotAuthorizedError`,
  `ParameterMissing`, `RecordNotFound`, `RecordInvalid`, `RecordNotDestroyed` and
  `APIError::StandardError`, so use bang methods and raise `APIError::*`.
- Render through `render_resource`, `render_resource_collection` and
  `render_resource_errors`. See `.claude/rules/serializers-and-errors.md`.
- A new sign-in or sign-out path must also be added to `jwt.dispatch_requests` or
  `jwt.revocation_requests` in `config/initializers/devise.rb`, or it issues or
  revokes no token.

## Pagination is broken until someone fixes it

No endpoint paginates yet, so nothing has caught this. On the installed pagy 9.3.4,
`render_resource_collection(records, pagy:)` raises `Pagy::VariableError` ("expected
:metadata to contain known keys; got :items") and the request returns 500. Measured
through a real request. Pagy 9 renamed `items` to `limit`, so also:

- `page[size]` is ignored, because `paginate` passes `items:`; every page has 20 rows
- `Pagy::DEFAULT[:items] = 25` has no effect
- `page[number]=abc` raises `Pagy::VariableError`, which `ExceptionFilter` does not map

The first paginated endpoint has to fix this, and must say so in its report:

| File | Change |
| --- | --- |
| `config/initializers/pagy.rb` | `DEFAULT[:limit] = 25`; `:limit` instead of `:items` in `DEFAULT[:metadata]` |
| `app/controllers/concerns/pagination.rb` | `pagy(collection, page: page_number, limit: page_size)`; `limit: :page_size` in `PAGY_KEYS_TRANSFORMER` |
| `app/controllers/concerns/pagination.rb` | Cap `page_size`, since the client now controls it |
| `app/controllers/concerns/exception_filter.rb` | Map `Pagy::VariableError` to `APIError::BadRequestError` |

`paginate` returns `[pagy, records]`, not a pagy object:

```ruby
pagy, products = paginate(policy_scope(Product).order(:created_at, :id))
render_resource_collection(products, pagy:)
```
