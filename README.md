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

It can also sort on relations:

```ruby
Property.sort(addresses: :id).to_sql
# => "...INNER JOIN addresses ON addresses.property_id = properties.id
# => "   ORDER BY addresses.id ASC"

Property.sort(addresses: {id: :desc}).to_sql
# => "...INNER JOIN addresses ON addresses.property_id = properties.id
# => "   ORDER BY addresses.id DESC"

Property.sort(addresses: {id: {asc: :nulls_frist}}).to_sql
# => "...INNER JOIN addresses ON addresses.property_id = properties.id
# => "   ORDER BY addresses.id ASC NULLS FIRST"
```
