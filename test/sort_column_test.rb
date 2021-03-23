require 'test_helper'

class SortColumnTest < ActiveSupport::TestCase

  test '::sort(nil)' do
    assert_equal('SELECT "properties".* FROM "properties"', Property.sort(nil).to_sql)
  end

  test "::sort('column')" do
    assert_equal('SELECT "properties".* FROM "properties" ORDER BY "properties"."id" ASC', Property.sort('id').to_sql.gsub(/\s+/, ' '))
  end
  
  test '::sort(:column)' do
    assert_equal('SELECT "properties".* FROM "properties" ORDER BY "properties"."id" ASC', Property.sort(:id).to_sql.gsub(/\s+/, ' '))
  end

  test '::sort(:column1, :column2)' do
    assert_equal('SELECT "properties".* FROM "properties" ORDER BY "properties"."id" ASC, "properties"."name" ASC', Property.sort(:id, :name).to_sql.gsub(/\s+/, ' '))
  end

  test '::sort(column: :desc)' do
    assert_equal('SELECT "properties".* FROM "properties" ORDER BY "properties"."id" DESC', Property.sort('id' => 'desc').to_sql.gsub(/\s+/, ' '))
  end

  test '::sort(column: {asc: :nulls_first})' do
    assert_equal('SELECT "properties".* FROM "properties" ORDER BY "properties"."id" ASC NULLS FIRST', Property.sort(:id => {'asc' => 'nulls_first'}).to_sql.gsub(/\s+/, ' '))
  end

  test '::sort(column: {asc: :nulls_last})' do
    assert_equal('SELECT "properties".* FROM "properties" ORDER BY "properties"."id" ASC NULLS LAST', Property.sort(:id => {'asc' => 'nulls_last'}).to_sql.gsub(/\s+/, ' '))
  end

  test '::sort(column: {desc: :nulls_first})' do
    assert_equal('SELECT "properties".* FROM "properties" ORDER BY "properties"."id" DESC NULLS FIRST', Property.sort(:id => {'desc' => 'nulls_first'}).to_sql.gsub(/\s+/, ' '))
  end

  test '::sort(column: {desc: :nulls_last})' do
    assert_equal('SELECT "properties".* FROM "properties" ORDER BY "properties"."id" DESC NULLS LAST', Property.sort(:id => {'desc' => 'nulls_last'}).to_sql.gsub(/\s+/, ' '))
  end
end
