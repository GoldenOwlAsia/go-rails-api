---
name: create-endpoint
description: Expose an existing model over the API with the route, controller, Pundit policy, Blueprinter serializer, rswag request spec and regenerated swagger, wired the way this app already does it. Use whenever the model exists and the task is adding or extending an endpoint, a controller action or a CRUD resource, even if the user never says "controller". If the model does not exist yet, implement-feature handles it instead.
---

Endpoint: $ARGUMENTS

An endpoint here is never one file. If the model does not exist yet either, this is a
multi-layer feature: use `implement-feature`.

## 1. Decide the shape first

- **Base class.** `API::V1::BaseController`, which enforces `authenticate_user!`. Only an
  auth flow needing Devise behaviour inherits `Devise::*Controller`. Add a route under
  `namespace :api` / `namespace :v1`.
- **Logic.** A mutation beyond one `save` belongs in an operation (`create-operation`). A
  filtered or sorted index belongs in a query (`create-query`).
- **Collection size.** A list that can grow must paginate, and pagination is currently
  broken. Read "Pagination is broken" in `.claude/rules/controllers.md` first: the first
  paginated endpoint carries that fix, and your report has to say so.

## 2. The files that move together

| Layer | Where |
| --- | --- |
| route | `config/routes.rb` |
| controller | `app/controllers/api/v1/<resources>_controller.rb` |
| policy | `app/policies/<model>_policy.rb`, plus `Scope#resolve` for a collection |
| serializer | `app/serializers/<model>_serializer.rb` |
| request spec | `spec/requests/api/v1/<resources>_request_spec.rb`, rswag DSL |
| policy spec | `spec/policies/<model>_policy_spec.rb` |
| factory | `spec/factories/<models>.rb`, if missing |
| docs | `swagger/v1/swagger.yaml`, generated |

Skipping the authorization is the failure that matters, because nothing raises when it is
missing. Call `authorize` in **every** action, on the fetched record rather than just the
class, and use `policy_scope` for collections. `spec/architecture_spec.rb` only notices a
controller with none at all.

## 3. Shape of a controller

```ruby
module API
  module V1
    class ProductsController < BaseController
      def show
        render_resource(authorize(Product.find(params[:id])))
      end

      def create
        authorize(Product)
        product = Product.create!(product_params)
        render_resource(product, status: :created)
      end

      private

      def product_params
        params.require(:product).permit(:name, :price)
      end
    end
  end
end
```

`create!` and `find` are enough: `ExceptionFilter` renders the 422 and 404. Do not write
those branches by hand, and do not rescue. The rules for responses are in
`.claude/rules/serializers-and-errors.md`.

## 4. Request spec

Copy `spec/requests/api/v1/blobs_request_spec.rb`. Start with
`require 'swagger_helper'`. Cover the success response plus each failure this endpoint
really produces: 401 with no token, 403 from the policy, 404, 422. List `required:` in each
`schema`, or the spec passes on a body missing those keys.

## 5. Verify

RuboCop and `zeitwerk:check` run in the Stop hook. Yours to run and paste:

- `bin/rails routes -g <resources>`
- `bundle exec rspec spec/requests/api/v1/<resources>_request_spec.rb spec/policies spec/architecture_spec.rb`
- `bin/rake rswag`, then `git diff swagger/`: only your endpoint's hunks
- for anything touching auth or permissions, dispatch `reviewer-agent` (Security section)
  over the diff

Report the files added, the authorization rule you implemented, and the commands you ran.
