# ActiveRecord::Sort

`ActiveRecord::Sort` provides and easy way to accept user input and order a query by the input.

Installation
------------

Add `sunstone` to your Gemfile and run `bundle`:

```ruby
gem 'activerecord-sort', require: 'active_record/sort'
```

Or install the gem and require it:

```sh
gem install activerecord-sort
irb
# => require('active_record/sort')
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

Property.sort(id: {asc: :nulls_first})
# => "...ORDER BY properties.id ASC NULLS FIRST"

Property.sort(id: {asc: :nulls_last})
# => "...ORDER BY properties.id ASC NULLS LAST"
```

It can also sort on relations. A relation sort groups by the sorted table's
primary key — so each record appears once and records with no associated
rows are still included — and orders by an aggregate of the requested
column: `MIN` ascending or `MAX` descending, keying each record by the
member you'd expect to see first in that direction:

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
