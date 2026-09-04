require 'test_helper'

class HasManySortTest < ActiveSupport::TestCase

  schema do
    create_table "addresses", force: :cascade do |t|
      t.integer  "name"
      t.integer  "property_id"
    end

    create_table "properties", force: :cascade do |t|
      t.string   "name",                 limit: 255
    end
  end

  class Address < ActiveRecord::Base
    belongs_to :property
  end

  class Property < ActiveRecord::Base
    has_many :addresses
  end

  # multi's addresses are created first, so it has the lowest address ids
  # and the lowest address name; empty has no addresses at all.
  fixtures do
    multi = Property.create!(name: 'multi')
    multi.addresses.create!(name: 2)
    multi.addresses.create!(name: 1)
    single = Property.create!(name: 'single')
    single.addresses.create!(name: 3)
    Property.create!(name: 'empty')
  end

  test '::sort(:has_many_relationship => :column)' do
    query = Property.sort(addresses: :id)

    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.gsub(/\s+/, ' '))
      SELECT "properties".* FROM "properties"
      LEFT OUTER JOIN "addresses" ON "addresses"."property_id" = "properties"."id"
      GROUP BY "properties"."id"
      ORDER BY MIN("addresses"."id") ASC
    SQL

    assert_equal ['multi', 'single', 'empty'], query.map(&:name)
  end

  test '::sort(:has_many_relationship => {:column => :desc})' do
    query = Property.sort(addresses: {id: :desc})

    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.gsub(/\s+/, ' '))
      SELECT "properties".* FROM "properties"
      LEFT OUTER JOIN "addresses" ON "addresses"."property_id" = "properties"."id"
      GROUP BY "properties"."id"
      ORDER BY MAX("addresses"."id") DESC
    SQL

    assert_equal ['empty', 'single', 'multi'], query.map(&:name)
  end

  test '::sort(:has_many_relationship => {:column => {:asc => :nulls_first}})' do
    query = Property.sort(addresses: {id: {asc: :nulls_first}})

    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.gsub(/\s+/, ' '))
      SELECT "properties".* FROM "properties"
      LEFT OUTER JOIN "addresses" ON "addresses"."property_id" = "properties"."id"
      GROUP BY "properties"."id"
      ORDER BY MIN("addresses"."id") ASC NULLS FIRST
    SQL

    assert_equal ['empty', 'multi', 'single'], query.map(&:name)
  end

  test '::sort(:has_many_relationship => {:column => {:desc => :nulls_last}})' do
    query = Property.sort(addresses: {id: {desc: :nulls_last}})

    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.gsub(/\s+/, ' '))
      SELECT "properties".* FROM "properties"
      LEFT OUTER JOIN "addresses" ON "addresses"."property_id" = "properties"."id"
      GROUP BY "properties"."id"
      ORDER BY MAX("addresses"."id") DESC NULLS LAST
    SQL

    assert_equal ['single', 'multi', 'empty'], query.map(&:name)
  end

  test '::sort(:has_many_relationship => :column) returns each record once and keeps records without members' do
    names = Property.sort(addresses: {name: {asc: :nulls_last}}).map(&:name)

    assert_equal names.uniq, names
    assert_equal ['multi', 'single', 'empty'], names
  end

  test '::sort(:has_many_relationship => {:column => :invalid}) raises' do
    assert_raises(ActiveRecord::StatementInvalid) do
      Property.sort(addresses: {id: :invalid})
    end
  end

  test '::sort(:has_many_relationship => nil_column) raises' do
    assert_raises(ActiveRecord::Sort::InvalidSort) do
      Property.sort(addresses: {nil => :asc})
    end
  end

  test '::sort(:has_many_relationship => non_string_column) raises' do
    assert_raises(ActiveRecord::Sort::InvalidSort) do
      Property.sort(addresses: 123)
    end
  end

  test '::sort(:has_many_relationship => {:column => :invalid_nulls}) raises' do
    assert_raises(ActiveRecord::Sort::InvalidSort) do
      Property.sort(addresses: {id: {asc: :nulls_invalid}})
    end
  end

  test '::sort(:has_many_relationship => {:column => {:asc => nil}})' do
    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), Property.sort(addresses: {id: {asc: nil}}).to_sql.gsub(/\s+/, ' '))
      SELECT "properties".* FROM "properties"
      LEFT OUTER JOIN "addresses" ON "addresses"."property_id" = "properties"."id"
      GROUP BY "properties"."id" ORDER BY MIN("addresses"."id") ASC
    SQL
  end

end
