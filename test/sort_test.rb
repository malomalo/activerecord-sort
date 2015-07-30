require 'test_helper'

class SortTest < ActiveSupport::TestCase

  test '::sort(nil)' do
    assert_equal('SELECT "properties".* FROM "properties"', Property.sort(nil).to_sql)
  end
  
  test '::sort(:invalid)' do
    assert_raises(ActiveRecord::StatementInvalid) do
      Property.sort(:invalid_column)#.to_sql
    end
  end
  
  test '::sort(:id => :invalid)' do
    assert_raises(ActiveRecord::StatementInvalid) do
      Property.sort(:id => :invalid)
    end
  end
  
  test '::sort(:id => {:asc => :nulls_invalid})' do
    assert_raises(ActiveRecord::StatementInvalid) do
      Property.sort(:id => :invalid)
    end
  end

end
