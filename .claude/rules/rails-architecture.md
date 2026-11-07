# Where logic goes

Decide the layer before writing code. Most bad Rails code is correct logic in
the wrong place.

**What most Rails writing calls a Service Object is an Operation here, in
`app/operations`. There is no `app/services` and you must not create one.**

## Decision table

| The work is | Put it in | Do not |
| --- | --- | --- |
| A business workflow with several steps or several models | Operation (`app/operations`) | Grow the controller action, or bury the flow in a model callback |
| A complex or dynamic read: filters, sorting, reports | Query object (`app/queries`) | Repeat the same ActiveRecord chain across controllers |
| Who may do what | Pundit policy (`app/policies`) | `if current_user.admin?` scattered through controllers |
| Whitelisting request attributes | A private `*_params` method on the controller | `params.permit!`, or passing raw `params` to a model |
| The JSON shape of a resource | Blueprinter serializer (`app/serializers`) | `render json: record`, or building hashes in a controller |
| A failure the client should see | `raise APIError::*` (`app/errors/api_error`) | `render json: { error: ... }` by hand |
| A domain invariant that is always true of the record | Model validation, backed by a constraint | A rule only one endpoint needs |
| Computed values shared by several serializers | Decorator (`app/decorators`) or a model method | The same block copied between serializers |
| Behaviour genuinely shared by several models or controllers | Concern | A concern used as a bin to make a class shorter |
| Reopening a class from a gem | `app/overrides/**/*_override.rb` | A monkey patch in an initializer |
| Several writes that must all succeed or all fail | Explicit transaction | Wrapping a single ordinary save |

## Operation or model?

An operation earns its place when there is a *workflow*: several writes, several
collaborators, or a sequence someone has to be able to read.

Line count is not the test. A long method about the record's own state belongs
on the model; a short method that coordinates three objects belongs in an
operation. Do not create an operation that only wraps `Model.create(...)` or
`model.update(...)`.

Name operations with verbs: `Users::Approve`, not `Users::Approver`.

## Concern or operation?

- Concern: a module of *shared behaviour* mixed into several classes.
- Operation: a class that performs *one action* and holds its collaborators.

A concern that only one class includes is that class's own code moved to a
different file. Splitting a class to make it shorter is not architecture.

## Layers this repo does not have

There is no `app/services`, `app/forms`, `app/interactors`, `app/presenters`,
`app/components` or `app/permit_params`. `spec/architecture_spec.rb` fails if
`app/services`, `app/forms`, `app/interactors` or `app/presenters` appears.

Introducing a layer creates a convention for the whole team. First check whether
an operation plus a model validation already covers the case. If you still need
one, say explicitly that you are introducing a new layer; do not do it quietly.

## Before adding any abstraction

Search for the existing equivalent first. A second parallel pattern costs more
than the duplication it removes.
