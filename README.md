# ActiveRecord::Sort

`ActiveRecord::Sort` provides an easy, safe way to accept user input and order a
query by it. Only recognized columns and associations produce SQL — anything
else raises `ActiveRecord::StatementInvalid`, so it's safe to pass request
parameters straight through.

Requirements
------------

- Rails / ActiveRecord >= 8.0

Installation
------------

Add `activerecord-sort` to your Gemfile and run `bundle`:

```ruby
gem 'activerecord-sort', require: 'active_record/sort'
```

Or install the gem and require it:

```sh
gem install activerecord-sort
```

```ruby
require 'active_record/sort'
```

Examples
--------
`ActiveRecord::Sort` supports the following cases:

```ruby
Property.sort(:id).to_sql
# => "...ORDER BY properties.id ASC"

Property.sort(:id, :name).to_sql
# => "...ORDER BY properties.id ASC, properties.name ASC"

Property.sort(id: :desc).to_sql
# => "...ORDER BY properties.id DESC"

Property.sort(id: {asc: :nulls_first}).to_sql
# => "...ORDER BY properties.id ASC NULLS FIRST"

Property.sort(id: {asc: :nulls_last}).to_sql
# => "...ORDER BY properties.id ASC NULLS LAST"
```

It can also sort on relations. A relation sort groups by the sorted table's
primary key — so each record appears once and records with no associated
rows are still included — and orders by an aggregate of the requested
column: `MIN` ascending or `MAX` descending, keying each record by the
member you'd expect to see first in that direction. A record with no
associated rows has a `NULL` sort key; where `NULL`s land is
database-dependent, so pass `nulls_first`/`nulls_last` to place those
records explicitly:

```ruby
Property.sort(addresses: :id).to_sql
# => "SELECT properties.* FROM properties
# => "   LEFT OUTER JOIN addresses ON addresses.property_id = properties.id
# => "   GROUP BY properties.id
# => "   ORDER BY MIN(addresses.id) ASC"

Property.sort(addresses: {id: :desc}).to_sql
# => "...ORDER BY MAX(addresses.id) DESC"

Property.sort(addresses: {id: {asc: :nulls_first}}).to_sql
# => "...ORDER BY MIN(addresses.id) ASC NULLS FIRST"

Property.sort(tags: :name).to_sql # has_and_belongs_to_many
# => "SELECT properties.* FROM properties
# => "   LEFT OUTER JOIN properties_tags ON properties_tags.property_id = properties.id
# => "   LEFT OUTER JOIN tags ON tags.id = properties_tags.tag_id
# => "   GROUP BY properties.id
# => "   ORDER BY MIN(tags.name) ASC"
```

A relation sort is order-only — it never adds or removes records — so
aggregates on a sorted relation (`count`, `sum`, `average`, `minimum`,
`maximum`) are computed over the records themselves, not the sort's
grouped and joined rows.

Order randomly:

```ruby
Property.sort(:random).to_sql
# => "...ORDER BY RANDOM()"
```

Unrecognized columns raise, so unfiltered params can't inject SQL:

```ruby
Property.sort(:name_or_something_unexpected)
# => raises ActiveRecord::Sort::InvalidSort
```

`ActiveRecord::Sort::InvalidSort` subclasses `ActiveRecord::StatementInvalid`,
so existing `rescue ActiveRecord::StatementInvalid` handlers keep catching bad
sort parameters, while callers that want to can rescue the narrower class.

Called with no arguments, `#sort` behaves like Ruby's `Enumerable#sort` —
it loads the records and sorts them by `<=>` — rather than building a query:

```ruby
Property.all.sort            # => Array of Property, sorted by <=>
Property.sort(nil)           # => relation (unchanged), for chaining
```
