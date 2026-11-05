---
name: api-contract-audit
description: Audit what this API promises against what it does, comparing routes, controllers, policies, serializers, request specs and swagger, and report findings with file:line and a fix. Read-only, it never edits. Use whenever asked to audit or review the API, check for endpoints missing authorization or specs, or check whether the swagger docs are accurate. Not for repo-wide config or version drift (repo-consistency-audit), and not for reviewing one diff (reviewer-agent).
allowed-tools: Read, Grep, Glob, Bash
---

Audit: $ARGUMENTS (default: every route under `/api/v1`)

Report findings. Do not edit anything, and do not run `bin/rake rswag`: it rewrites the
committed swagger file. Use a read of the file instead.

## 1. Build the inventory

```sh
bin/rails routes -g api/v1
```

For each route, find its controller action, policy method, serializer, and the matching `path`
in `spec/requests/api/v1`. Add the routes outside `/api/v1` too: `/sidekiq`, `/docs`, `/blobs`,
`/disk`, `/up`, and `root`.

## 2. What to check, worst first

- **Authorization.** An action with no `authorize` is open to every signed-in user, and nothing
  raises. Check each action, not each file. An action authorizing only the class while
  loading a record by id is an IDOR. `Auth::ProfilesController` acts on `current_user` and is
  allowed to skip it.
- **Authentication.** A controller outside `API::V1::BaseController`, and which of its actions
  are public on purpose.
- **Exposure.** Every field in the serializer: should a client see it? Compare with the table's
  columns in `db/schema.rb`. Permit lists: is a privilege field writable?
- **Undocumented failures.** A status the action can produce that has no `response` block:
  401, 403, 404, 422. Conversely, a documented status nothing produces.
- **Schema honesty.** A `schema` with no `required:` passes on a body missing those keys. A
  property the serializer no longer returns, or a field it returns that the schema omits.
- **Shape.** Anything off the shapes in `.claude/rules/serializers-and-errors.md`, such as a
  hand-built `render json:`.
- **Pagination.** A list action that does not paginate, or one that paginates while the breakage
  described in `.claude/rules/controllers.md` is unfixed. `paginate` also has no size cap.
- **Unmapped exceptions.** Client input that reaches a 500: a bad sort column,
  `page[number]=abc`, a `filter_params` call with no `filter`.
- **Stale docs.** A `path` in `swagger/v1/swagger.yaml` with no route, or a route with no `path`.

## 3. Prove what you can

Read-only proof is welcome: `bundle exec rspec` on the relevant request spec, and
`bin/rails runner` for inspection. A finding you could not confirm is reported as *unverified*,
with what would confirm it.

## Report format

Group by severity. For each finding:

**Issue**, then **route**, then **file:line**, then **what a client can do or will see**, then
**the fix** as this repo would write it.

- **P0**: a client can reach data or actions it should not
- **P1**: the API returns 500 on client input, or breaks its documented contract
- **P2**: documentation or spec gaps

Close with a table of every route and its authorization, spec and docs status, so the report is
also the inventory. Say what already holds up, not just what does not.
