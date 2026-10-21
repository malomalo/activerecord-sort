require 'test_helper'

class CalculationsSortTest < ActiveSupport::TestCase

  schema do
    create_table "properties", force: :cascade do |t|
      t.string   "name",                 limit: 255
      t.integer  "views"
      t.boolean  "active",               default: true
    end

    create_table "tags", force: :cascade do |t|
      t.string   "name",                 limit: 255
    end

    create_table "properties_tags", id: false, force: :cascade do |t|
      t.integer  "property_id"
      t.integer  "tag_id"
    end
  end

  class Tag < ActiveRecord::Base
  end

  class Property < ActiveRecord::Base
    has_and_belongs_to_many :tags
  end

  class ScopedProperty < ActiveRecord::Base
    self.table_name = 'properties'
    default_scope { where(active: true) }
    has_and_belongs_to_many :tags, join_table: 'properties_tags', foreign_key: 'property_id'
  end

  # single is the one inactive property, hidden by ScopedProperty's
  # default scope.
  fixtures do
    Property.create!(name: 'multi', views: 10, tags: [Tag.create!(name: 'Zoo'), Tag.create!(name: 'Apex')])
    Property.create!(name: 'single', views: 20, active: false, tags: [Tag.create!(name: 'Mall')])
    Property.create!(name: 'untagged', views: 30)
  end

  test '::sort(:column).count returns the record count' do
    assert_equal 3, Property.sort(:name).count
  end

  test '::sort(:habtm_relationship => :column).count returns the record count' do
    assert_equal 3, Property.sort(tags: {name: :asc}).count
  end

  test '::sort(:habtm_relationship => :column).where(...).count applies the conditions' do
    assert_equal 2, Property.sort(tags: {name: :asc}).where.not(tags: {id: nil}).count
  end

  # Aggregates are computed over the records, not the sort's grouped and
  # fanned-out rows — multi's two tags don't double its views.
  test '::sort(:habtm_relationship => :column).sum returns the record total despite the join fan-out' do
    assert_equal 60, Property.sort(tags: {name: :asc}).sum(:views)
  end

  test '::sort(:habtm_relationship => :column) average/minimum/maximum aggregate over the records' do
    query = Property.sort(tags: {name: :asc})

    assert_equal 20, query.average(:views)
    assert_equal 10, query.minimum(:views)
    assert_equal 30, query.maximum(:views)
  end

  test '::sort(:habtm_relationship => :column) with an additional group falls through to grouped aggregates' do
    counts = Property.sort(tags: {name: :asc}).group(:name).count

    assert_kind_of Hash, counts
  end

  # The aggregate covers the relation's records, so a default scope the
  # relation removed stays removed; one it keeps still applies.
  test '::unscoped.sort(:habtm_relationship => :column) aggregates over every record' do
    query = ScopedProperty.unscoped.sort(tags: :name)

    assert_equal 3, query.to_a.size
    assert_equal 3, query.count
    assert_equal 60, query.sum(:views)
  end

  test '::unscope(where: ...).sort(:habtm_relationship => :column) aggregates without the removed condition' do
    query = ScopedProperty.unscope(where: :active).sort(tags: :name)

    assert_equal 3, query.to_a.size
    assert_equal 3, query.count
    assert_equal 60, query.sum(:views)
  end

  test '::sort(:habtm_relationship => :column) on a default scoped model aggregates over the scoped records' do
    query = ScopedProperty.sort(tags: :name)

    assert_equal 2, query.to_a.size
    assert_equal 2, query.count
    assert_equal 40, query.sum(:views)
  end

end
