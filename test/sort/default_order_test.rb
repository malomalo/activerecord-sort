require 'test_helper'

# Rails 8.2 adds default_order, an order applied only when a relation has no
# other order.
class DefaultOrderTest < ActiveSupport::TestCase

  schema do
    create_table "addresses", force: :cascade do |t|
      t.string   "name"
      t.integer  "likes"
      t.integer  "property_id"
    end

    create_table "properties", force: :cascade do |t|
      t.string   "name",                 limit: 255
      t.integer  "likes"
    end
  end

  class Address < ActiveRecord::Base
    belongs_to :property
  end

  class Property < ActiveRecord::Base
    if ActiveRecord::Relation.method_defined?(:default_order)
      has_many :addresses, default_order: :likes
    else
      has_many :addresses
    end
  end

  # Ordered by likes, a and b are the reverse of ordered by name.
  fixtures do
    a = Property.create!(name: 'a', likes: 2)
    Property.create!(name: 'b', likes: 1)
    a.addresses.create!(name: 'y', likes: 1)
    a.addresses.create!(name: 'x', likes: 2)
  end

  setup do
    skip 'default_order is Rails 8.2+' if !ActiveRecord::Relation.method_defined?(:default_order)
  end

  test '#sort overrides the default_order' do
    query = Property.default_order(:likes).sort(:name)
    assert_sql(<<-SQL, query)
      SELECT "properties".* FROM "properties" ORDER BY "properties"."name" ASC
    SQL
    assert_equal %w[a b], query.map(&:name)

    a = Property.find_by!(name: 'a')
    query = a.addresses.sort(:name)
    assert_sql(<<-SQL, query)
      SELECT "addresses".* FROM "addresses" WHERE "addresses"."property_id" = #{a.id}
      ORDER BY "addresses"."name" ASC
    SQL
    assert_equal %w[x y], query.map(&:name)
  end

  test '#resort overrides the default_order' do
    query = Property.default_order(:likes).resort(:name)
    assert_sql(<<-SQL, query)
      SELECT "properties".* FROM "properties" ORDER BY "properties"."name" ASC
    SQL
    assert_equal %w[a b], query.map(&:name)

    a = Property.find_by!(name: 'a')
    query = a.addresses.resort(:name)
    assert_sql(<<-SQL, query)
      SELECT "addresses".* FROM "addresses" WHERE "addresses"."property_id" = #{a.id}
      ORDER BY "addresses"."name" ASC
    SQL
    assert_equal %w[x y], query.map(&:name)
  end

  test '#resort with no ordering leaves the default_order, as reorder(nil) does' do
    a = Property.find_by!(name: 'a')
    addresses = a.addresses.order(:name)

    [addresses.resort(nil), addresses.resort, addresses.reorder(nil)].each do |query|
      assert_sql(<<-SQL, query)
        SELECT "addresses".* FROM "addresses" WHERE "addresses"."property_id" = #{a.id}
        ORDER BY "addresses"."likes" ASC
      SQL
      assert_equal %w[y x], query.map(&:name)
    end
  end

  test '#sort by a relation overrides the default_order' do
    query = Property.default_order(:likes).sort(addresses: :name)

    assert_sql(<<-SQL, query)
      SELECT "properties".* FROM "properties"
      LEFT OUTER JOIN "addresses" ON "addresses"."property_id" = "properties"."id"
      GROUP BY "properties"."id"
      ORDER BY MIN("addresses"."name") ASC
    SQL
    assert_equal %w[a b], query.map(&:name)
    assert_equal 1, query.limit(1).count
  end

  test 'a blank relation sort leaves the default_order to order the grouped records' do
    query = Property.default_order(:likes).sort(addresses: nil)

    assert_sql(<<-SQL, query)
      SELECT "properties".* FROM "properties"
      GROUP BY "properties"."id"
      ORDER BY "properties"."likes" ASC
    SQL
    assert_equal %w[b a], query.map(&:name)
  end

  test '#reverse_order reverses a relation sort, not the default_order' do
    query = Property.default_order(:likes).sort(addresses: {name: {asc: :nulls_last}}).reverse_order

    assert_sql(<<-SQL, query)
      SELECT "properties".* FROM "properties"
      LEFT OUTER JOIN "addresses" ON "addresses"."property_id" = "properties"."id"
      GROUP BY "properties"."id"
      ORDER BY MIN("addresses"."name") DESC NULLS FIRST
    SQL
    assert_equal %w[b a], query.map(&:name)
  end

end
