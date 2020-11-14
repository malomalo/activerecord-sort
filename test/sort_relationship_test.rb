require 'test_helper'

class SortRelationTest < ActiveSupport::TestCase

  test '::sort(:has_many_relationship => :column)' do
    query = Property.sort(:addresses => :id)

    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.gsub(/\s+/, ' '))
      SELECT "properties".* FROM "properties"
      INNER JOIN "addresses" ON "addresses"."property_id" = "properties"."id"
      ORDER BY "addresses"."id" ASC
    SQL
  end

  test '::sort(:has_many_relationship => {:column => :desc})' do
    query = Property.sort(:addresses => {:id => :desc})

    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.gsub(/\s+/, ' '))
      SELECT "properties".* FROM "properties"
      INNER JOIN "addresses" ON "addresses"."property_id" = "properties"."id"
      ORDER BY "addresses"."id" DESC
    SQL
  end

  test '::sort(:has_many_relationship => {:column => {:asc => :nulls_first}})' do
    query = Property.sort(:addresses => {:id => {:asc => :nulls_first}})

    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.gsub(/\s+/, ' '))
      SELECT "properties".* FROM "properties"
      INNER JOIN "addresses" ON "addresses"."property_id" = "properties"."id"
      ORDER BY "addresses"."id" ASC NULLS FIRST
    SQL
  end

  test '::sort(:has_many_relationship => {:column => {:desc => :nulls_last}})' do
    query = Property.sort(:addresses => {:id => {:desc => :nulls_last}})

    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.gsub(/\s+/, ' '))
      SELECT "properties".* FROM "properties"
      INNER JOIN "addresses" ON "addresses"."property_id" = "properties"."id"
      ORDER BY "addresses"."id" DESC NULLS LAST
    SQL
  end

  test '::sort(:belongs_to_relationship => {:column => :desc})' do
    query = Address.sort(:property => {:id => :desc})

    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.gsub(/\s+/, ' '))
      SELECT "addresses".* FROM "addresses"
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
