require 'test_helper'

# Rails 8.2 adds default_order, an order applied only when a relation has no
# other order.
class DefaultOrderTest < ActiveSupport::TestCase

  schema do
    create_table "addresses", force: :cascade do |t|
      t.string   "name"
      t.integer  "likes"
      t.integer  "property_id"
    end

    create_table "properties", force: :cascade do |t|
      t.string   "name",                 limit: 255
      t.integer  "likes"
    end
  end

  class Address < ActiveRecord::Base
    belongs_to :property
  end

  class Property < ActiveRecord::Base
    if ActiveRecord::Relation.method_defined?(:default_order)
      has_many :addresses, default_order: :likes
    else
      has_many :addresses
    end
  end

  # Ordered by likes, a and b are the reverse of ordered by name.
  fixtures do
    a = Property.create!(name: 'a', likes: 2)
    Property.create!(name: 'b', likes: 1)
    a.addresses.create!(name: 'y', likes: 1)
    a.addresses.create!(name: 'x', likes: 2)
  end

  setup do
    skip 'default_order is Rails 8.2+' if !ActiveRecord::Relation.method_defined?(:default_order)
  end

  test '#sort overrides the default_order' do
    assert_equal %w[a b], Property.default_order(:likes).sort(:name).map(&:name)
    assert_equal %w[x y], Property.find_by!(name: 'a').addresses.sort(:name).map(&:name)
  end

  test '#resort overrides the default_order' do
    assert_equal %w[a b], Property.default_order(:likes).resort(:name).map(&:name)
    assert_equal %w[x y], Property.find_by!(name: 'a').addresses.resort(:name).map(&:name)
  end

  test '#resort with no ordering leaves the default_order, as reorder(nil) does' do
    addresses = Property.find_by!(name: 'a').addresses.order(:name)

    assert_equal addresses.reorder(nil).to_sql, addresses.resort(nil).to_sql
    assert_equal %w[y x], addresses.resort(nil).map(&:name)
    assert_equal %w[y x], addresses.resort.map(&:name)
  end

  test '#sort by a relation overrides the default_order' do
    query = Property.default_order(:likes).sort(addresses: :name)

    assert_no_match(/"properties"\."likes"/, query.to_sql)
    assert_equal %w[a b], query.map(&:name)
    assert_equal 1, query.limit(1).count
  end

  test 'a blank relation sort leaves the default_order to order the grouped records' do
    assert_equal %w[b a], Property.default_order(:likes).sort(addresses: nil).map(&:name)
  end

  test '#reverse_order reverses a relation sort, not the default_order' do
    query = Property.default_order(:likes).sort(addresses: {name: {asc: :nulls_last}}).reverse_order

    assert_no_match(/"properties"\."likes"/, query.to_sql)
    assert_equal %w[b a], query.map(&:name)
  end

end
