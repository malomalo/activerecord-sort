require 'test_helper'

class HasOneSortTest < ActiveSupport::TestCase

  schema do
    create_table "deeds", force: :cascade do |t|
      t.string   "name",                 limit: 255
      t.integer  "property_id"
    end

    create_table "properties", force: :cascade do |t|
      t.string   "name",                 limit: 255
    end
  end

  class Deed < ActiveRecord::Base
    belongs_to :property
  end

  class Property < ActiveRecord::Base
    has_one :deed
  end

  # zebra sorts first by deed name (A-Deed < Z-Deed) and by deed
  # property_id (created first); deedless has no deed at all.
  fixtures do
    Property.create!(name: 'zebra', deed: Deed.create!(name: 'A-Deed'))
    Property.create!(name: 'acorn', deed: Deed.create!(name: 'Z-Deed'))
    Property.create!(name: 'deedless')
  end

  test '::sort(:has_one_relationship => :column)' do
    query = Property.sort(deed: :name)

    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.gsub(/\s+/, ' '))
      SELECT "properties".* FROM "properties"
      LEFT OUTER JOIN "deeds" ON "deeds"."property_id" = "properties"."id"
      GROUP BY "properties"."id"
      ORDER BY MIN("deeds"."name") ASC
    SQL

    assert_equal ['zebra', 'acorn', 'deedless'], query.map(&:name)
  end

  test '::sort(:has_one_relationship => {:column => :desc})' do
    query = Property.sort(deed: {name: :desc})

    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.gsub(/\s+/, ' '))
      SELECT "properties".* FROM "properties"
      LEFT OUTER JOIN "deeds" ON "deeds"."property_id" = "properties"."id"
      GROUP BY "properties"."id"
      ORDER BY MAX("deeds"."name") DESC
    SQL

    assert_equal ['deedless', 'acorn', 'zebra'], query.map(&:name)
  end

  test '::sort(:has_one_relationship => {:column => {:asc => :nulls_first}})' do
    query = Property.sort(deed: {name: {asc: :nulls_first}})

    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.gsub(/\s+/, ' '))
      SELECT "properties".* FROM "properties"
      LEFT OUTER JOIN "deeds" ON "deeds"."property_id" = "properties"."id"
      GROUP BY "properties"."id"
      ORDER BY MIN("deeds"."name") ASC NULLS FIRST
    SQL

    assert_equal ['deedless', 'zebra', 'acorn'], query.map(&:name)
  end

  test '::sort(:has_one_relationship => {:column => {:desc => :nulls_last}})' do
    query = Property.sort(deed: {name: {desc: :nulls_last}})

    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.gsub(/\s+/, ' '))
      SELECT "properties".* FROM "properties"
      LEFT OUTER JOIN "deeds" ON "deeds"."property_id" = "properties"."id"
      GROUP BY "properties"."id"
      ORDER BY MAX("deeds"."name") DESC NULLS LAST
    SQL

    assert_equal ['acorn', 'zebra', 'deedless'], query.map(&:name)
  end

  test '::sort(:has_one_relationship => {:column => ""}) defaults to ascending' do
    query = Property.sort(deed: {name: ''})

    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.gsub(/\s+/, ' '))
      SELECT "properties".* FROM "properties"
      LEFT OUTER JOIN "deeds" ON "deeds"."property_id" = "properties"."id"
      GROUP BY "properties"."id"
      ORDER BY MIN("deeds"."name") ASC
    SQL

    assert_equal ['zebra', 'acorn', 'deedless'], query.map(&:name)
  end

  test '::sort(:has_one_relationship => {:column => :invalid}) raises' do
    assert_raises(ActiveRecord::StatementInvalid) do
      Property.sort(deed: {name: :invalid})
    end
  end

  test '::sort(:has_one_relationship => [columns]) sorts by multiple columns' do
    query = Property.sort(deed: [{name: :asc}, {property_id: :desc}])

    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.gsub(/\s+/, ' '))
      SELECT "properties".* FROM "properties"
      LEFT OUTER JOIN "deeds" ON "deeds"."property_id" = "properties"."id"
      GROUP BY "properties"."id"
      ORDER BY MIN("deeds"."name") ASC, MAX("deeds"."property_id") DESC
    SQL

    assert_equal ['zebra', 'acorn', 'deedless'], query.map(&:name)
  end

  # The sort column lives only in the ORDER BY, never the select list, so
  # it can't overwrite a same-named attribute on the base record.
  test '::sort(:has_one_relationship => :column) does not clobber a same-named attribute on the base record' do
    query = Property.sort(deed: {name: {asc: :nulls_last}})

    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.gsub(/\s+/, ' '))
      SELECT "properties".* FROM "properties"
      LEFT OUTER JOIN "deeds" ON "deeds"."property_id" = "properties"."id"
      GROUP BY "properties"."id"
      ORDER BY MIN("deeds"."name") ASC NULLS LAST
    SQL

    assert_equal ['zebra', 'acorn', 'deedless'], query.map(&:name)
  end

  test '::sort(:has_one_relationship => :column) with a non-colliding sort column leaves attributes intact' do
    query = Property.sort(deed: {property_id: :asc})

    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.gsub(/\s+/, ' '))
      SELECT "properties".* FROM "properties"
      LEFT OUTER JOIN "deeds" ON "deeds"."property_id" = "properties"."id"
      GROUP BY "properties"."id"
      ORDER BY MIN("deeds"."property_id") ASC
    SQL

    assert_equal ['zebra', 'acorn', 'deedless'], query.map(&:name)
  end

  test '::sort(:has_one_relationship => :column) keeps records without an associated record' do
    assert_equal ['zebra', 'acorn', 'deedless'], Property.sort(deed: {name: {asc: :nulls_last}}).map(&:name)
    assert_equal ['acorn', 'zebra', 'deedless'], Property.sort(deed: {name: {desc: :nulls_last}}).map(&:name)
  end

end
