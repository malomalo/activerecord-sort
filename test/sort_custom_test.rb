require 'test_helper'

class SortCustomTest < ActiveSupport::TestCase

  class Listing < ActiveRecord::Base
    self.table_name = 'properties'
    sort_on(:id) { |_options| order(id: :desc) }
  end

  test '::sort_on registers a custom sort' do
    assert Property.sorts.key?(:by_name)
  end

  test '::sort(:custom_sort)' do
    assert_equal(
      'SELECT "properties".* FROM "properties" ORDER BY "properties"."name" ASC',
      Property.sort(:by_name).to_sql.gsub(/\s+/, ' ')
    )
  end

  test '::sort(:custom_sort => :desc)' do
    assert_equal(
      'SELECT "properties".* FROM "properties" ORDER BY "properties"."name" DESC',
      Property.sort(:by_name => :desc).to_sql.gsub(/\s+/, ' ')
    )
  end

  test '::sort(:custom_sort) applies dependent joins' do
    sql = Property.sort(:by_address_count => :desc).to_sql.gsub(/\s+/, ' ')
    assert_includes sql, 'INNER JOIN "addresses"'
    assert_includes sql, 'COUNT("addresses"."id") DESC'
    assert_includes sql, 'GROUP BY "properties"."id"'
  end

  test '::sort_on can override an existing column' do
    assert_equal(
      'SELECT "properties".* FROM "properties" ORDER BY "properties"."id" DESC',
      Listing.sort(:id).to_sql.gsub(/\s+/, ' ')
    )
  end

  test '::sort raises for unknown sort' do
    assert_raises(ActiveRecord::StatementInvalid) do
      Property.sort(:does_not_exist)
    end
  end

end
