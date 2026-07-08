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
  
  test '::sort(:has_one_relationship => :column)' do
    query = Property.sort(:deed => :name)

    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.gsub(/\s+/, ' '))
      SELECT "properties".*, "deeds"."name" AS ar_sort_0 FROM "properties"
      LEFT OUTER JOIN "deeds" ON "deeds"."property_id" = "properties"."id"
      ORDER BY "deeds"."name" ASC
    SQL
  end

  test '::sort(:has_one_relationship => {:column => :desc})' do
    query = Property.sort(:deed => {:name => :desc})

    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.gsub(/\s+/, ' '))
      SELECT "properties".*, "deeds"."name" AS ar_sort_0 FROM "properties"
      LEFT OUTER JOIN "deeds" ON "deeds"."property_id" = "properties"."id"
      ORDER BY "deeds"."name" DESC
    SQL
  end

  test '::sort(:has_one_relationship => {:column => {:asc => :nulls_first}})' do
    query = Property.sort(:deed => {:name => {:asc => :nulls_first}})

    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.gsub(/\s+/, ' '))
      SELECT "properties".*, "deeds"."name" AS ar_sort_0 FROM "properties"
      LEFT OUTER JOIN "deeds" ON "deeds"."property_id" = "properties"."id"
      ORDER BY "deeds"."name" ASC NULLS FIRST
    SQL
  end

  test '::sort(:has_one_relationship => {:column => {:desc => :nulls_last}})' do
    query = Property.sort(:deed => {:name => {:desc => :nulls_last}})

    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.gsub(/\s+/, ' '))
      SELECT "properties".*, "deeds"."name" AS ar_sort_0 FROM "properties"
      LEFT OUTER JOIN "deeds" ON "deeds"."property_id" = "properties"."id"
      ORDER BY "deeds"."name" DESC NULLS LAST
    SQL
  end

  test '::sort(:has_one_relationship => [columns]) aliases each sort column with its own index' do
    query = Property.sort(:deed => [{:name => :asc}, {:property_id => :desc}])

    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.gsub(/\s+/, ' '))
      SELECT "properties".*, "deeds"."name" AS ar_sort_0, "deeds"."property_id" AS ar_sort_1 FROM "properties"
      LEFT OUTER JOIN "deeds" ON "deeds"."property_id" = "properties"."id"
      ORDER BY "deeds"."name" ASC, "deeds"."property_id" DESC
    SQL
  end

  # The sort column is selected under an ar_sort_* alias so it can't
  # overwrite a same-named attribute on the base record.
  test '::sort(:has_one_relationship => :column) does not clobber a same-named attribute on the base record' do
    Property.create!(name: 'zebra', deed: Deed.create!(name: 'A-Deed'))
    Property.create!(name: 'acorn', deed: Deed.create!(name: 'Z-Deed'))
    Property.create!(name: 'deedless')

    query = Property.sort(:deed => {:name => {:asc => :nulls_last}})

    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.gsub(/\s+/, ' '))
      SELECT "properties".*, "deeds"."name" AS ar_sort_0 FROM "properties"
      LEFT OUTER JOIN "deeds" ON "deeds"."property_id" = "properties"."id"
      ORDER BY "deeds"."name" ASC NULLS LAST
    SQL

    assert_equal ['zebra', 'acorn', 'deedless'], query.map(&:name)
  end

  test '::sort(:has_one_relationship => :column) with a non-colliding sort column leaves attributes intact' do
    Property.create!(name: 'zebra', deed: Deed.create!(name: 'A-Deed'))
    Property.create!(name: 'acorn', deed: Deed.create!(name: 'Z-Deed'))

    query = Property.sort(:deed => {:property_id => :asc})

    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.gsub(/\s+/, ' '))
      SELECT "properties".*, "deeds"."property_id" AS ar_sort_0 FROM "properties"
      LEFT OUTER JOIN "deeds" ON "deeds"."property_id" = "properties"."id"
      ORDER BY "deeds"."property_id" ASC
    SQL

    assert_equal ['zebra', 'acorn'], query.map(&:name)
  end

  test '::sort(:has_one_relationship => :column) keeps records without an associated record' do
    zebra = Property.create!(name: 'zebra', deed: Deed.create!(name: 'A-Deed'))
    acorn = Property.create!(name: 'acorn', deed: Deed.create!(name: 'Z-Deed'))
    deedless = Property.create!(name: 'deedless')

    assert_equal [zebra.id, acorn.id, deedless.id], Property.sort(:deed => {:name => {:asc => :nulls_last}}).map(&:id)
    assert_equal [acorn.id, zebra.id, deedless.id], Property.sort(:deed => {:name => {:desc => :nulls_last}}).map(&:id)
  end

end
