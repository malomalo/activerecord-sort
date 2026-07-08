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
  
  test '::sort(:has_many_relationship => :column)' do
    query = Property.sort(:addresses => :id)

    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.gsub(/\s+/, ' '))
      SELECT "properties".*, "addresses"."id" AS ar_sort_0 FROM "properties"
      INNER JOIN "addresses" ON "addresses"."property_id" = "properties"."id"
      ORDER BY "addresses"."id" ASC
    SQL
  end

  test '::sort(:has_many_relationship => {:column => :desc})' do
    query = Property.sort(:addresses => {:id => :desc})

    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.gsub(/\s+/, ' '))
      SELECT "properties".*, "addresses"."id" AS ar_sort_0 FROM "properties"
      INNER JOIN "addresses" ON "addresses"."property_id" = "properties"."id"
      ORDER BY "addresses"."id" DESC
    SQL
  end

  test '::sort(:has_many_relationship => {:column => {:asc => :nulls_first}})' do
    query = Property.sort(:addresses => {:id => {:asc => :nulls_first}})

    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.gsub(/\s+/, ' '))
      SELECT "properties".*, "addresses"."id" AS ar_sort_0 FROM "properties"
      INNER JOIN "addresses" ON "addresses"."property_id" = "properties"."id"
      ORDER BY "addresses"."id" ASC NULLS FIRST
    SQL
  end

  test '::sort(:has_many_relationship => {:column => {:desc => :nulls_last}})' do
    query = Property.sort(:addresses => {:id => {:desc => :nulls_last}})

    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.gsub(/\s+/, ' '))
      SELECT "properties".*, "addresses"."id" AS ar_sort_0 FROM "properties"
      INNER JOIN "addresses" ON "addresses"."property_id" = "properties"."id"
      ORDER BY "addresses"."id" DESC NULLS LAST
    SQL
  end

end
