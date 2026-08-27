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

It can also sort on associations:

```ruby
Property.sort(addresses: :id).to_sql
# => "...INNER JOIN addresses ON addresses.property_id = properties.id
# => "   ORDER BY addresses.id ASC"

Property.sort(addresses: {id: :desc}).to_sql
# => "...INNER JOIN addresses ON addresses.property_id = properties.id
# => "   ORDER BY addresses.id DESC"

Property.sort(addresses: {id: {asc: :nulls_first}}).to_sql
# => "...INNER JOIN addresses ON addresses.property_id = properties.id
# => "   ORDER BY addresses.id ASC NULLS FIRST"
```

Order randomly:

```ruby
Property.sort(:random).to_sql
# => "...ORDER BY RANDOM()"
```

Unrecognized columns raise, so unfiltered params can't inject SQL:

```ruby
Property.sort(:name_or_something_unexpected)
# => raises ActiveRecord::StatementInvalid
```

Called with no arguments, `#sort` behaves like Ruby's `Enumerable#sort` —
it loads the records and sorts them by `<=>` — rather than building a query:

```ruby
Property.all.sort            # => Array of Property, sorted by <=>
Property.sort(nil)           # => relation (unchanged), for chaining
```
