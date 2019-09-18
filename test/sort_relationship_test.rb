require 'test_helper'

class SortColumnTest < ActiveSupport::TestCase

  test '::sort(:has_many_relationship => :column)' do
    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), Property.sort(:addresses => :id).to_sql.gsub(/\s+/, ' '))
      SELECT "properties".* FROM "properties"
      INNER JOIN "addresses" ON "addresses"."property_id" = "properties"."id"
      ORDER BY "addresses"."id" ASC
    SQL
  end

  test '::sort(:has_many_relationship => {:column => :desc})' do
    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), Property.sort(:addresses => {:id => :desc}).to_sql.gsub(/\s+/, ' '))
      SELECT "properties".* FROM "properties"
      INNER JOIN "addresses" ON "addresses"."property_id" = "properties"."id"
      ORDER BY "addresses"."id" DESC
    SQL
  end

  test '::sort(:has_many_relationship => {:column => {:asc => :nulls_first}})' do
    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), Property.sort(:addresses => {:id => {:asc => :nulls_first}}).to_sql.gsub(/\s+/, ' '))
      SELECT "properties".* FROM "properties"
      INNER JOIN "addresses" ON "addresses"."property_id" = "properties"."id"
      ORDER BY "addresses"."id" ASC NULLS FIRST
    SQL
  end

  test '::sort(:has_many_relationship => {:column => {:desc => :nulls_last}})' do
    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), Property.sort(:addresses => {:id => {:desc => :nulls_last}}).to_sql.gsub(/\s+/, ' '))
      SELECT "properties".* FROM "properties"
      INNER JOIN "addresses" ON "addresses"."property_id" = "properties"."id"
      ORDER BY "addresses"."id" DESC NULLS LAST
    SQL
  end
  
  test '::sort(:belongs_to_relationship => {:column => :desc})' do
    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), Address.sort(:property => {:id => :desc}).to_sql.gsub(/\s+/, ' '))
      SELECT "addresses".* FROM "addresses"
      LEFT OUTER JOIN "properties" ON "properties"."id" = "addresses"."property_id"
      ORDER BY "properties"."id" DESC
    SQL
  end

end
