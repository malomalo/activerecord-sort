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

    create_table "addresses", force: :cascade do |t|
      t.integer  "property_id"
    end
  end

  class Tag < ActiveRecord::Base
    has_and_belongs_to_many :properties
  end

  class Address < ActiveRecord::Base
  end

  class Property < ActiveRecord::Base
    has_and_belongs_to_many :tags
    has_many :addresses
  end

  class ScopedProperty < ActiveRecord::Base
    self.table_name = 'properties'
    default_scope { where(active: true) }
    has_and_belongs_to_many :tags, join_table: 'properties_tags', foreign_key: 'property_id'
  end

  # Addresses mirror the tags: multi has two, single one, untagged none.
  # single is the one inactive property, hidden by ScopedProperty's default
  # scope.
  fixtures do
    multi = Property.create!(name: 'multi', views: 10, tags: [Tag.create!(name: 'Zoo'), Tag.create!(name: 'Apex')])
    single = Property.create!(name: 'single', views: 20, active: false, tags: [Tag.create!(name: 'Mall')])
    Property.create!(name: 'untagged', views: 30)
    2.times { multi.addresses.create! }
    single.addresses.create!
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

  # limit and offset select records, not the sort's fanned-out rows, so
  # aggregates cover exactly the records the relation loads.
  test '::sort(:has_many_relationship => :column).limit(...).count counts the limited records' do
    assert_equal 2, Property.sort(addresses: :id).limit(2).count
    assert_equal 2, Property.sort(addresses: :id).limit(2).count(:all)
    assert_equal 2, Property.sort(addresses: :id).limit(2).count(:views)
  end

  test '::sort(:has_many_relationship => :column).offset(...).count counts the remaining records' do
    assert_equal 2, Property.sort(addresses: :id).offset(1).count
    assert_equal 1, Property.sort(addresses: :id).limit(1).offset(1).count
  end

  test '::sort(:has_many_relationship => :column).limit(...) aggregates over the records it loads' do
    query = Property.sort(addresses: {id: {asc: :nulls_last}}).limit(2)

    assert_equal ['multi', 'single'], query.map(&:name)
    assert_equal 30, query.sum(:views)
    assert_equal 15, query.average(:views)
    assert_equal 10, query.minimum(:views)
    assert_equal 20, query.maximum(:views)
  end

  test '::sort(:habtm_relationship => {:column => {:asc => :nulls_first}}).limit(...).sum follows the sort order' do
    query = Property.sort(tags: {name: {asc: :nulls_first}}).limit(1)

    assert_equal ['untagged'], query.map(&:name)
    assert_equal 30, query.sum(:views)
  end

  test '::sort(:has_many_relationship => :column).none.count returns 0' do
    assert_equal 0, Property.sort(addresses: :id).none.count
    assert_equal 0, Property.sort(addresses: :id).limit(2).none.count
  end

  test 'association.sort(:has_many_relationship => :column).limit(...) aggregates over the limited records' do
    query = Tag.find_by!(name: 'Zoo').properties.sort(addresses: :id)

    assert_equal 1, query.count
    assert_equal 1, query.limit(2).count
    assert_equal 10, query.limit(2).sum(:views)
    assert_equal 0, query.offset(1).count
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

  # Yields, then returns the [query, async] of each select_all the
  # connection was asked to run meanwhile.
  def select_alls
    connection = Property.connection
    queries = []
    connection.define_singleton_method(:select_all) do |arel, name = nil, binds = [], **options|
      queries << [arel, options[:async]]
      super(arel, name, binds, **options)
    end
    yield
    queries
  ensure
    connection.singleton_class.send(:remove_method, :select_all)
  end

  # Async calculations return a promise of the same aggregate, and the
  # query restricting it to the sorted records is run asynchronously, as
  # Rails runs its own. (No async executor is configured here, so Rails
  # still runs it in the foreground; what matters is that it's asked to.)
  test '::sort(:has_many_relationship => :column) async calculations return promises of the aggregates' do
    query = Property.sort(addresses: :id)

    {
      [:async_count]           => [3, 'COUNT(*)'],
      [:async_count, :views]   => [3, 'COUNT("properties"."views")'],
      [:async_sum, :views]     => [60, 'SUM("properties"."views")'],
      [:async_average, :views] => [20, 'AVG("properties"."views")'],
      [:async_minimum, :views] => [10, 'MIN("properties"."views")'],
      [:async_maximum, :views] => [30, 'MAX("properties"."views")']
    }.each do |(method, *args), (expected, aggregate)|
      promise = nil
      queries = select_alls { promise = query.public_send(method, *args) }

      assert promise.is_a?(ActiveRecord::Promise)
      assert_equal expected, promise.value
      assert_equal 1, queries.size
      assert_equal true, queries[0][1]
      assert_sql(<<-SQL, queries[0][0])
        SELECT #{aggregate} FROM "properties"
        WHERE "properties"."id" IN (SELECT "properties"."id" FROM "properties"
        LEFT OUTER JOIN "addresses" ON "addresses"."property_id" = "properties"."id"
        GROUP BY "properties"."id"
        ORDER BY MIN("addresses"."id") ASC)
      SQL
    end
  end

  test '::sort(:has_many_relationship => :column).limit(...) async calculations aggregate over the limited records' do
    query = Property.sort(addresses: {id: {asc: :nulls_last}}).limit(2)

    assert_equal 2, query.async_count.value
    assert_equal 30, query.async_sum(:views).value
  end

  test '::sort(:has_many_relationship => :column).none async calculations return promises of 0' do
    assert_equal 0, Property.sort(addresses: :id).none.async_count.value
    assert_equal 0, Property.sort(addresses: :id).none.async_sum(:views).value
  end

  test '::sort(:has_many_relationship => :column) with an additional group falls through to async grouped aggregates' do
    assert_kind_of Hash, Property.sort(addresses: :id).group(:name).async_count.value
  end

  # async_pluck, async_pick and async_ids don't go through calculate, so
  # the override never sees them; they still work on the sorted relation.
  test '::sort(:has_many_relationship => :column) async_pluck, async_pick and async_ids follow the sort' do
    query = Property.sort(addresses: {id: {asc: :nulls_last}})

    assert_equal ['multi', 'single', 'untagged'], query.async_pluck(:name).value
    assert_equal 'multi', query.async_pick(:name).value
    assert_equal query.map(&:id), query.async_ids.value
  end

  test 'async calculations on a relation without a relation sort are unchanged' do
    [Property.all, Property.sort(:name)].each do |query|
      assert_equal 3, query.async_count.value
      assert_equal 60, query.async_sum(:views).value
      assert_equal 20, query.async_average(:views).value
      assert_equal 10, query.async_minimum(:views).value
      assert_equal 30, query.async_maximum(:views).value
    end
  end

end
