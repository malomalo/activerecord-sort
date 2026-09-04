# Changelog

## Unreleased

### Changed

- An unrecognized value in the nulls position now raises
  `ActiveRecord::Sort::InvalidSort` instead of being silently dropped.
  `sort(:name => {:asc => :nulls_frist})` previously ordered by a plain
  `ASC`, quietly returning results in the wrong null order; it now raises,
  like any other unknown sort value. A blank nulls value still means "no
  `NULLS` clause" rather than an invalid one — `""` (what query params
  send) and `nil` (what JSON sends) are both absent, not wrong.

### Fixed

- Directions and nulls values are now matched case-insensitively wherever
  they appear. `sort(:name => 'DESC')` already downcased, but the hash forms
  did not, so `sort(:name => {'DESC' => 'NULLS_LAST'})` raised on the same
  input the bare form accepted.
- `sort(:name => {})` now sorts ascending instead of raising. An empty hash
  states no direction, which is what `""` (from a query string) and `nil`
  (from JSON) already meant; the blank check simply sat after the hash
  check and so never saw it.
- Sort parameters holding `nil` or a non-string key no longer raise
  `NoMethodError`. `{"name" => {"asc" => nil}}`, `{"name" => {nil =>
  "asc"}}` and a non-string column such as `{123 =>
  "asc"}` — all reachable from a JSON request body, where a query string
  would send `""` — now raise `ActiveRecord::Sort::InvalidSort`, or sort
  normally where the value is merely absent, honoring the documented
  contract that unfiltered params are rescuable as
  `ActiveRecord::StatementInvalid`.

## [8.0.0] - 2026-08-27

### Breaking changes

- Relation sorts are unified across association types. Sorting by any
  relation (`has_many`, `has_and_belongs_to_many`, `has_one`,
  `belongs_to`) now `LEFT OUTER JOIN`s the association, groups by the
  sorted table's primary key, and orders by an aggregate of the requested
  column. For `has_many` sorts this changes behavior:
  - each record is returned once, instead of once per associated row
    (the join no longer fans out into duplicates)
  - records with no associated rows are included (previously dropped by
    the `INNER JOIN`)
- Descending relation sorts key each record by its largest member
  (`MAX`), ascending by its smallest (`MIN`) — the member you'd expect
  to see first in that direction. For records with multiple associated
  rows, descending is therefore not the reverse of ascending: a record
  holding both extremes sorts first in both directions.
- Sort columns are no longer added to the `SELECT`:
  - loaded records keep their own attributes — a joined sort column can
    no longer overwrite a same-named attribute on the base record
    (previously even `id` could be clobbered)
  - `pluck` and `ids` keep the sort (previously raised on
    `has_and_belongs_to_many` sorts)
  - a caller's `select` is left untouched
  - chaining `.distinct` after a relation sort now raises: PostgreSQL
    requires `ORDER BY` expressions to appear in the select list for
    `SELECT DISTINCT`. It previously appeared to work while silently
    deduplicating over the wrong tuple.
- A bare `belongs_to`/`has_one` sort with no direction (e.g.
  `Address.sort(property: :name)`) now defaults to ascending, matching
  every other sort form (previously descending).
- An unknown sort direction on a relation sort (e.g. `:dsc`) now raises
  `ActiveRecord::Sort::InvalidSort` (previously sorted ascending
  silently), matching column sorts.

### Added

- Sorting by `has_and_belongs_to_many` relations.
- Unrecognized sort columns, associations, and directions raise
  `ActiveRecord::Sort::InvalidSort`, a subclass of
  `ActiveRecord::StatementInvalid` — so existing
  `rescue ActiveRecord::StatementInvalid` handlers still catch bad sort
  parameters, while callers can rescue the narrower class. Relation sort
  columns are now validated up front (against the associated model's
  columns) instead of only failing once the query reaches the database.
- Sorts of different types compose: they can be combined in one call
  (`Property.sort(:name, tags: :name, addresses: :id)`) or chained
  (`.sort(...).sort(...)`), sharing a single `GROUP BY`.
- Aggregates on a sorted relation (`count`, `sum`, `average`, `minimum`,
  `maximum`) are computed over the records themselves rather than the
  sort's grouped, joined rows — `count` returns the record count instead
  of a per-group `Hash`, and multi-member records aren't weighted once
  per member. A caller-supplied `group` still gets standard grouped
  results.
- A blank direction (`''`, as query parameters often produce) is
  accepted as ascending on all sort forms.
- `ActionController::Parameters` are accepted for relation sorts, and
  their nulls option (`nulls_first`/`nulls_last`) is honored.

### Fixed

- `has_and_belongs_to_many` sorts crashed with `NoMethodError` on
  ActiveRecord <= 8.0 (`Function#as` mutates and returns the receiver
  there).
- Combining a `has_and_belongs_to_many` sort with another relation sort
  raised `PG::GroupingError`.

## [7.0.0] - 2026-08-27

The gem's version is now independent of the Rails version it targets.

### Breaking Changes

- Removed the public `random_sort` method. Use `sort(:random)` instead.

### Changed

- Require `activerecord >= 8.0.0, < 9.0`; support for Rails 7.1 and 7.2 has
  been dropped.
- Require `arel-extensions >= 9.0.0`.
- `#sort` called with no arguments now falls back to Ruby's `Enumerable#sort`
  (loads the records and sorts them by `<=>`) instead of returning the
  relation. Pass arguments to use the ordering DSL; `sort(nil)` and `sort([])`
  still return the relation for chaining.

### Internal

- The `sort`, `sort_for_column`, and `sort_for_relation` methods are now
  defined in an `ActiveRecord::Sort` module prepended onto
  `ActiveRecord::QueryMethods`, rather than reopening `QueryMethods` directly.
  Relations still respond to them, but they no longer appear in
  `ActiveRecord::QueryMethods.public_instance_methods(false)` — which keeps
  Rails' internal delegation invariants intact.

[8.0.0]: https://github.com/malomalo/activerecord-sort/releases/tag/v8.0.0
[7.0.0]: https://github.com/malomalo/activerecord-sort/releases/tag/v7.0.0
