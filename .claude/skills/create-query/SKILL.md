---
name: create-query
description: Add a Query object (app/queries) for a complex or dynamic read, such as filters, sorting, search or reports, built on ApplicationQuery's filter and sort helpers and returning a relation, with a spec. Use whenever the user wants a filterable or sortable list, a search param, a report, or the same ActiveRecord chain is being repeated across controllers. Not for writes (an operation), not for the JSON shape (a serializer), and not when the query is one layer of a larger feature (implement-feature sequences that).
---

Query: $ARGUMENTS

If this is one piece of a feature you are also building, use `implement-feature`. A read
that changes data is an operation. The full convention is in
`.claude/rules/operations-and-queries.md`, which loads when you open a query file.

## 1. Check it earns a query

A query object is for a read that is complex or dynamic: several optional filters,
user-chosen sorting, joins, a report. One fixed `where` belongs as a scope on the model.
Two controllers repeating the same chain is the sign to extract. No query exists yet beyond
the sample in `app/queries/application_query.rb`, so you are setting the pattern.

## 2. Shape

```ruby
module Products
  class GeneralQuery < ApplicationQuery
    SORTABLE_COLUMNS = %w[name price created_at].freeze

    def call(scope = Product.all, **params)
      scope = filter(scope, :by_term, params[:term])
      scope = filter(scope, :by_max_price, params[:max_price])
      sort(scope, allowed_sort(params[:sort])).order(:id)
    end

    private

    def by_term(scope, term)
      scope.where('name ILIKE ?', "%#{Product.sanitize_sql_like(term)}%")
    end

    def by_max_price(scope, price)
      scope.where(price: ..price)
    end

    def allowed_sort(value)
      value if SORTABLE_COLUMNS.include?(value.to_s.delete_prefix('-').delete_prefix('+'))
    end
  end
end
```

File at `app/queries/products/general_query.rb`. Subclass `ApplicationQuery`;
`spec/architecture_spec.rb` fails otherwise.

## 3. The traps

- **`sort` is not allowlisted.** An unknown column raises `ActiveRecord::StatementInvalid`
  and returns 500 (measured). Check the value before calling `sort`.
- **Ordering.** Primary keys are random UUIDs, so end with a unique tiebreaker such as
  `:id`, or a paginated list can repeat one row and drop another.
- **Never interpolate user input into SQL.** Use placeholders.
- **Eager loading.** Choose from how the result is consumed, including what the serializer
  reads. Bullet flags real N+1s in development.

## 4. Wire it up

A query with no caller is where contract bugs hide, so call it from the controller. Do not
splat `params`: it raises, or passes string keys that make every filter silently do nothing.
Use the `query_params` pattern in `.claude/rules/operations-and-queries.md`, and pass
`policy_scope(Model)` as the scope so authorization applies before filtering.

If the list paginates, read "Pagination is broken" in `.claude/rules/controllers.md`.

## 5. Spec

`spec/queries/products/general_query_spec.rb`, starting with `require 'rails_helper'`. Cover:
returns a relation, returns everything with no filter, each filter excludes a non-matching
record, a blank filter is ignored, sorting asc and desc, an unlisted sort column is ignored,
and it composes onto a passed scope. Add a request-level example proving the params really
reach the filter, because that is where a key mismatch hides.

## 6. Verify

Yours to run and paste:

- `bundle exec rspec spec/queries spec/architecture_spec.rb`
- `bundle exec rubocop app/queries spec/queries`
- `bin/rails zeitwerk:check`

Report the files added, the allowed filters and sort columns, how ordering and eager loading
were decided, and the commands you ran.
