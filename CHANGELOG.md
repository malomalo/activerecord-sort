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

[7.0.0]: https://github.com/malomalo/activerecord-sort/releases/tag/v7.0.0
