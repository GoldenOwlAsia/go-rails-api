---
paths:
  - "spec/**/*.rb"
  - "swagger/**/*.yaml"
---

# Specs

RSpec with `infer_spec_type_from_file_location!`, so a file's directory sets its type.
Do not pass `type:`. FactoryBot, shoulda-matchers, pundit-matchers and SimpleCov are
wired up; files in `spec/supports/` load automatically.

- `.rspec` only loads `spec_helper`. Start a new spec with `require 'rails_helper'`, or
  `require 'swagger_helper'` for a request spec. Some existing specs omit it and need
  `-r rails_helper` when run alone. Do not copy that.
- Reproduce a bug with a failing spec before fixing it whenever practical.
- Assert behaviour, not implementation.
- `create` hits the database; prefer `build` when persistence is irrelevant.
- Use `described_class` rather than repeating the class name.
- Never weaken or delete a spec to make the suite green. If a spec is wrong, say so and
  explain why before changing it.
- Never write a spec that would still pass if the feature were deleted.

## Request specs are the API documentation

`spec/requests` uses the rswag DSL (`path`, `response`, `schema`, `run_test!`), and
`bin/rake rswag` generates the committed `swagger/v1/swagger.yaml` from it.

- Cover at least the success response and each failure the endpoint really produces:
  401 with no token, 403 from the policy, 404, 422.
- Auth is `let(:Authorization) { auth_header(user) }`, with
  `security [bearer_auth: {}]` on the operation.
- Helpers are in `spec/supports/jsonapi.rb`: `json_response` and `auth_header`.
- `schema` validates only what it lists, and only properties marked `required`. A schema
  with no `required:` passes on a body missing those keys.
- `run_test!` checks the status and schema. Pass a block for further assertions.
- Regenerate after changing an API, and keep only your endpoint's hunks in the diff.

## Policies

Authorization deserves explicit specs. Use `permit_actions` and `forbid_actions` from
pundit-matchers, as `spec/policies/active_storage/blob_policy_spec.rb` does, and cover
both an allowed user and a denied one.

## Architecture

`spec/architecture_spec.rb` asserts the shape of the codebase: which layer directories
may exist, which base class each layer inherits, and the greppable boundary violations.
It is the enforcement half of `.claude/rules/rails-architecture.md`. Treat a failure as a
design question, not a test to silence. If it blocks work you believe is right, change
the rule and the example together and say so.

This repo has no CI, so the spec only protects anyone who runs the suite. Run it.
