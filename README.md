# ActiveRecord::sort [![Travis CI](https://travis-ci.org/malomalo/activerecord-sort.svg?branch=master)](https://travis-ci.org/malomalo/activerecord-sort)

`ActiveRecord::sort` provides and easy way to accept user input and order a query by the input.

Installtion
-----------

- Add `gem 'activerecord-sort', require: 'active_record/sort'
- Run `bundle install`

Examples
--------
`ActiveRecord::sort` supports the following cases:

```ruby
Property.order(:id).to_sql
# => "...ORDER BY properties.id ASC"

Property.order(:id, :name).to_sql
# => "...ORDER BY properties.id ASC, properties.name ASC"

Property.order(:id => :desc).to_sql
# => "...ORDER BY properties.id DESC"

Property.order(:id => {:asc => :nulls_first})
# => "...ORDER BY properties.id ASC NULLS FIRST"

Property.order(:id => {:asc => :nulls_last})
# => "...ORDER BY properties.id ASC NULLS LAST"
```

It can also sort on relations:

```ruby
Property.order(:addresses => :id).to_sql
# => "...INNER JOIN addresses ON addresses.property_id = properties.id
# => "   ORDER BY addresses.id ASC"

Property.order(:addresses => {:id => :desc}).to_sql
# => "...INNER JOIN addresses ON addresses.property_id = properties.id
# => "   ORDER BY addresses.id DESC"

Property.order(:addresses => {:id => {:asc => :nulls_frist}}).to_sql
# => "...INNER JOIN addresses ON addresses.property_id = properties.id
# => "   ORDER BY addresses.id ASC NULLS FIRST"
```
