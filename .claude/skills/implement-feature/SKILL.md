---
name: implement-feature
description: Build a feature that spans several layers of this Rails API by first finding an analogous existing implementation, then placing each piece in the layer that already exists for it. Use when new functionality needs more than one layer, such as a model plus an endpoint, policy and serializer. A lone migration, endpoint, operation, query, job or mailer has its own skill.
---

Implement: $ARGUMENTS

## Phase 1: Explore before designing

For a large or unclear feature, dispatch `reviewer-agent` (read-only, Architecture section)
for this phase. It produces a layer-by-layer plan and is the place to argue for a new
abstraction. For a small, clearly analogous feature, do the following directly.

1. Find the closest existing feature and read it end to end.
   `app/controllers/api/v1/blobs_controller.rb` plus `Blobs::Create`, `BlobPolicy`,
   `BlobSerializer` and their specs is the fullest worked example.
2. List which existing layers the work needs.
3. If you believe a new architectural pattern is required, stop and say why before writing
   it. The default answer is that an existing layer fits.

## Phase 2: Agree the plan

State the layers you will touch, the files you will add, the authorization rule, the
response shape, and what the specs will assert. Keep it short. Get agreement before writing
code for anything non-trivial.

## Phase 3: Build

Write the spec first where it is practical.

The order that works here: migration, model, policy, operation or query, serializer,
controller and route, request spec and swagger, then any job or mailer.

`.claude/rules/` loads the conventions as you open each file. Verify each layer before
starting the next, and never let a later layer paper over an earlier one being wrong: a
model tightening what the migration should have enforced, or a controller inlining logic
an operation should own.

For each layer, follow the skill that owns it rather than restating it here:
`create-migration`, `create-operation`, `create-query`, `create-endpoint`,
`create-job-or-mailer`.

## Phase 4: Verify

Run the commands in the Workflow section of `CLAUDE.md` that apply, and paste real output.

If the change went beyond one trivial layer, or touches auth, policies, uploads or routes,
dispatch `reviewer-agent` now. Your own verification passing is not the same as a second
pass over the diff with fresh eyes.

## Phase 5: Review your own diff

Read `git diff` as a reviewer: an action with no `authorize`, an N+1 in a serializer, a
validation with no constraint behind it, a spec that would pass with the feature removed,
leftover debugging, unrelated churn.

Report files changed, commands run with results, and anything left undone.
