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

Custom Sorts
------------

Declare named sorts on a model with `sort_on`. The block is evaluated against
the relation and receives the options passed to `sort`, letting you build any
ordering expression you want. An optional second argument pre-applies joins
that the sort depends on.

```ruby
class Property < ActiveRecord::Base
  has_many :addresses

  sort_on(:by_name) { |options| order(name: options || :asc) }

  sort_on(:by_address_count, :addresses) do |options|
    direction = options.is_a?(Hash) ? options.keys.first : options
    order(Arel.sql("COUNT(addresses.id) #{direction || 'ASC'}")).group('properties.id')
  end
end

Property.sort(:by_name)
# => "...ORDER BY properties.name ASC"

Property.sort(by_name: :desc)
# => "...ORDER BY properties.name DESC"

Property.sort(by_address_count: :desc)
# => "...INNER JOIN addresses ON addresses.property_id = properties.id
# => "   GROUP BY properties.id
# => "   ORDER BY COUNT(addresses.id) DESC"
```

Custom sorts take precedence over matching column and relation names, so they
can also be used to override the default behavior for a given key.
