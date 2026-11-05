---
name: create-migration
description: Write a schema change on its own, such as a column, index, constraint or table, with the lock and backfill reasoning this app has no gem to do for it. Use when the migration is the whole task. If the schema change is one layer of a feature being built, implement-feature sequences it instead.
---

Schema change: $ARGUMENTS

If this is one layer of a feature you are also building, use `implement-feature`, which
orders the model, policy, operation and controller work around this step.

## 1. Establish the current shape

Read `db/schema.rb` for the tables involved, then the models: validations, associations and
existing indexes. Decide what the database must enforce versus what a model merely asserts.
A uniqueness validation with no unique index behind it is a race.

## 2. State the risk before writing

No `strong_migrations` or `good_migrations` is installed, so nothing here will stop an
unsafe migration. Say out loud, for this change:

- which lock it takes and on how large a table
- whether it rewrites the table
- whether existing rows need a backfill, which goes in a separate migration
- whether the code deployed alongside it works both before and after it runs

Always append a new migration. Never edit a committed one.

## 3. Write it

Generate with `bin/rails generate migration`. `.claude/rules/models-and-migrations.md` loads
when you open the file, and its Migrations section is the maintained checklist: UUID
references, concurrent indexes, `nulls_not_distinct`, foreign keys. Work from it.

Anything beyond a trivial column add: dispatch `reviewer-agent` (Database section) to audit
the plan before it is written.

## 4. Run it

In development, `db:migrate` also re-annotates the model, factory and serializer files, so
expect them in the diff. Do not hand-edit those headers.

## 5. Verify

Run the "Verify" commands in that rule file and paste the real output. Also check the
migration reverses: `bin/rails db:rollback` followed by `bin/rails db:migrate`, then confirm
`git diff db/schema.rb` shows only the intended change.

Report which hazards you ruled out and what you ran.
