require 'test_helper'

class SortTest < ActiveSupport::TestCase

  schema do
    create_table "properties", force: :cascade do |t|
      t.string   "name",                 limit: 255
    end
  end
  
  class Property < ActiveRecord::Base
    has_many :addresses
  end
  
  test '::sort(nil)' do
    assert_equal('SELECT "properties".* FROM "properties"', Property.sort(nil).to_sql)
  end
  
  test '::sort(:invalid)' do
    assert_raises(ActiveRecord::Sort::InvalidSort) do
      Property.sort(:invalid_column)#.to_sql
    end
  end

  # InvalidSort subclasses StatementInvalid, so callers relying on the
  # documented `rescue ActiveRecord::StatementInvalid` contract keep
  # catching bad sort parameters.
  test 'InvalidSort is rescuable as ActiveRecord::StatementInvalid' do
    assert ActiveRecord::Sort::InvalidSort < ActiveRecord::StatementInvalid

    error = assert_raises(ActiveRecord::StatementInvalid) do
      Property.sort(:invalid_column)
    end
    assert_kind_of ActiveRecord::Sort::InvalidSort, error
  end

  test '::sort(:random)' do
    assert_equal('SELECT "properties".* FROM "properties" ORDER BY RANDOM()', Property.sort(:random).to_sql.gsub(/\s+/, ' '))
  end

  test '::sort(:id => :invalid)' do
    assert_raises(ActiveRecord::Sort::InvalidSort) do
      Property.sort(:id => :invalid)
    end
  end

  # An unrecognized nulls value is a typo'd sort parameter, not something to
  # drop silently — the caller would otherwise get plausible-looking results
  # in the wrong null order.
  test '::sort(:id => {:asc => :nulls_invalid})' do
    assert_raises(ActiveRecord::Sort::InvalidSort) do
      Property.sort(:id => {:asc => :nulls_invalid})
    end
  end

  # "" is what a query string sends for null
  test '::sort(:column => {:asc => blank}) omits the NULLS clause' do
    ['', nil].each do |blank|
      assert_equal(
        'SELECT "properties".* FROM "properties" ORDER BY "properties"."name" ASC',
        Property.sort(:name => {:asc => blank}).to_sql.gsub(/\s+/, ' '),
        "expected #{blank.inspect} in the nulls position to omit the NULLS clause"
      )
    end
  end

  # Case is insignificant in every position a direction or nulls value can
  # appear, not just the bare `sort(:name => 'DESC')` form
  test '::sort(:column => {:DESC => :NULLS_LAST})' do
    assert_equal(
      'SELECT "properties".* FROM "properties" ORDER BY "properties"."name" DESC NULLS LAST',
      Property.sort(:name => {'DESC' => 'NULLS_LAST'}).to_sql.gsub(/\s+/, ' ')
    )
  end

  test '::sort(:column => {non_string_direction => :asc})' do
    assert_raises(ActiveRecord::Sort::InvalidSort) do
      Property.sort(:name => {123 => :asc})
    end
  end

  test '::sort(:name => {nil => :asc})' do
    assert_raises(ActiveRecord::Sort::InvalidSort) do
      Property.sort(:name => {nil => :asc})
    end
  end

  # {} states no direction, same as "" and nil
  test '::sort(:column => blank) sorts ascending' do
    ['', nil, {}].each do |blank|
      assert_equal(
        'SELECT "properties".* FROM "properties" ORDER BY "properties"."name" ASC',
        Property.sort(:name => blank).to_sql.gsub(/\s+/, ' '),
        "expected #{blank.inspect} in the direction position to sort ascending"
      )
    end
  end

  test '::sort(nil => :asc)' do
    assert_raises(ActiveRecord::Sort::InvalidSort) do
      Property.sort(nil => :asc)
    end
  end

  test '::sort(123 => :asc)' do
    assert_raises(ActiveRecord::Sort::InvalidSort) do
      Property.sort(123 => :asc)
    end
  end

  test '::sort({:a => 1} => :asc)' do
    assert_raises(ActiveRecord::Sort::InvalidSort) do
      Property.sort({:a => 1} => :asc)
    end
  end

end
