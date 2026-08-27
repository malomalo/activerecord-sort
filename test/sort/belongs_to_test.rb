require 'test_helper'

class BelongsToSortTest < ActiveSupport::TestCase

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

  # first is created before second so it has the lower property id;
  # address 3 has no property at all.
  fixtures do
    first  = Property.create!(name: 'first')
    second = Property.create!(name: 'second')
    Address.create!(name: 2, property: first)
    Address.create!(name: 1, property: second)
    Address.create!(name: 3)
  end

  test '::sort(:belongs_to_relationship => {:column => :desc})' do
    query = Address.sort(property: {id: :desc})

    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.gsub(/\s+/, ' '))
      SELECT "addresses".* FROM "addresses"
      LEFT OUTER JOIN "properties" ON "properties"."id" = "addresses"."property_id"
      GROUP BY "addresses"."id"
      ORDER BY MAX("properties"."id") DESC
    SQL

    assert_equal [3, 1, 2], query.map(&:name)
  end

  test '::sort(:belongs_to_relationship => {:column => :desc}).distinct_on' do
    query = Address.sort(property: {id: :desc}).distinct_on(:id)

    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.gsub(/\s+/, ' '))
      SELECT DISTINCT ON ( "addresses"."id" ) "addresses".* FROM "addresses"
      LEFT OUTER JOIN "properties" ON "properties"."id" = "addresses"."property_id"
      GROUP BY "addresses"."id"
      ORDER BY MAX("properties"."id") DESC
    SQL
  end

  test '::sort(:belongs_to_relationship => {:column => :invalid}) raises' do
    assert_raises(ActiveRecord::StatementInvalid) do
      Address.sort(property: {id: :invalid})
    end
  end

  test '::sort(:belongs_to_relationship => :unknown_column) raises' do
    assert_raises(ActiveRecord::StatementInvalid) do
      Address.sort(property: :not_a_column)
    end
  end

  # Chaining .distinct after a relation sort is not supported: the sort
  # column lives only in the ORDER BY, and for SELECT DISTINCT Postgres
  # requires ORDER BY expressions to appear in the select list. Better to
  # fail loudly than silently deduplicate over the wrong tuple.
  test '::sort(:belongs_to_relationship => {:column => :desc}).distinct raises' do
    assert_raises(ActiveRecord::StatementInvalid) do
      Address.sort(property: {id: :desc}).distinct.load
    end
  end

  # The sort column lives only in the ORDER BY, never the select list, so
  # it can't overwrite a same-named attribute on the base record — here
  # the primary key.
  test '::sort(:belongs_to_relationship => :column) does not clobber a same-named attribute on the base record' do
    query = Address.sort(property: {id: {asc: :nulls_last}})

    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.gsub(/\s+/, ' '))
      SELECT "addresses".* FROM "addresses"
      LEFT OUTER JOIN "properties" ON "properties"."id" = "addresses"."property_id"
      GROUP BY "addresses"."id"
      ORDER BY MIN("properties"."id") ASC NULLS LAST
    SQL

    assert_equal [2, 1, 3], query.map(&:name)
  end

  # test 'SunstoneRecord::sort(:belongs_to_relationship => {:column => :desc})' do
  #   webmock(:get, "/points", limit: 1, order: [{lines: {id: :desc}}]).to_return({
  #     body: [{id: 42}].to_json
  #   })

  #   assert_equal 42, Point.sort(:line => {:id => :desc}).first.id
  # end

end
