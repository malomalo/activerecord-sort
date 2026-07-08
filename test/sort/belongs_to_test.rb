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

  test '::sort(:belongs_to_relationship => {:column => :desc})' do
    query = Address.sort(:property => {:id => :desc})

    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.gsub(/\s+/, ' '))
      SELECT "addresses".*, "properties"."id" FROM "addresses"
      LEFT OUTER JOIN "properties" ON "properties"."id" = "addresses"."property_id"
      ORDER BY "properties"."id" DESC
    SQL
  end

  test '::sort(:belongs_to_relationship => {:column => :desc}).distinct_on' do
    query = Address.sort(:property => {:id => :desc}).distinct_on(:id)

    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.gsub(/\s+/, ' '))
      SELECT DISTINCT ON ( "addresses"."id" ) "addresses".*, "properties"."id" FROM "addresses"
      LEFT OUTER JOIN "properties" ON "properties"."id" = "addresses"."property_id"
      ORDER BY "properties"."id" DESC
    SQL
  end

  # test 'SunstoneRecord::sort(:belongs_to_relationship => {:column => :desc})' do
  #   webmock(:get, "/points", limit: 1, order: [{lines: {id: :desc}}]).to_return({
  #     body: [{id: 42}].to_json
  #   })

  #   assert_equal 42, Point.sort(:line => {:id => :desc}).first.id
  # end

end
