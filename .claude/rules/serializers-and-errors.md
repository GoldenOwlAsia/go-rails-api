---
paths:
  - "app/serializers/**/*.rb"
  - "app/decorators/**/*.rb"
  - "app/errors/**/*.rb"
  - "app/controllers/concerns/**/*.rb"
---

# Serializers and API errors

The helpers are named `JSONAPI*`, but responses are **not** JSON:API. Do not add
`type`, `attributes` or `relationships`. The shapes clients get are:

| Case | Body |
| --- | --- |
| One resource | The serialized object, with no root key |
| A collection | `{ "data": [...], "meta": {...} }` |
| An error | `{ "message": "...", "status": 404 }`, plus `errors` and `code` when present |
| A validation error (422) | `{ "message": "...", "status": 422, "errors": [{ "field": "...", "message": "..." }] }` |

## Serializers (`app/serializers`)

- Subclass `ApplicationSerializer`. List fields explicitly: the serializer is the
  allowlist of what leaves the API, so a new column is private until it is added.
- Never expose `encrypted_password`, `*_token`, `*_sign_in_ip` or similar columns.
- `render_resource` looks up `"#{Model}Serializer"`. Pass `serializer:` or
  `each_serializer:` when the name does not match: for arrays (where it is required)
  and for namespaced models such as `ActiveStorage::Blob`.
- `status:`, `pagy:`, `serializer:` and `each_serializer:` go to the render. Any other
  option, such as `view:` or `meta:`, goes to the serializer.
- Use a `view` for a fuller shape, as `BlobSerializer` does with `:detail`.
- Timestamps in `BlobSerializer` are integers (`to_i`). Match the resource you are
  extending rather than mixing formats within one response.
- An association read inside a serializer runs once per row. Eager load in the query
  that feeds a collection.

## Errors (`app/errors/api_error`)

- Raise from anywhere in a request and `ExceptionFilter` renders it. Do not rescue to
  re-render.
- Subclass `APIError::StandardError`, set `status:`, and register nothing else: the
  filter already catches the base class. Note that inside `module APIError`, a bare
  `StandardError` means `APIError::StandardError`.
- Constructors differ. `NotFoundError`, `NotAuthorizedError`, `NotAuthenticatedError`
  and `InternalServerError` take a positional message. `BadRequestError` and
  `UnprocessableEntityError` take `message:` and `errors:`. `RecordInvalidError` takes
  an `ActiveModel::Errors`, and `ParamMissingError` takes a param name.
- An exception `ExceptionFilter` does not map becomes Rails' default 500, which is
  the right outcome for a bug. Do not add a blanket `rescue_from StandardError`.
  `spec/architecture_spec.rb` fails on one.

## Decorators (`app/decorators`)

`SimpleDelegator` wrappers, with `wrap_all` for collections. None exist beyond the
base class yet. Use one only when a serializer needs values that do not belong on the
model.
