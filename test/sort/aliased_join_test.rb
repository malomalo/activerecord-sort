require 'test_helper'

# When a query joins the same table more than once, Rails aliases the later
# joins, and which join gets the alias depends on every join in the query.
# A relation sort has to order by the join of the association it was given,
# whatever that join ends up being called.
class AliasedJoinSortTest < ActiveSupport::TestCase

  schema do
    create_table "landlords", force: :cascade do |t|
      t.string   "name",                 limit: 255
      t.integer  "parent_id"
    end

    create_table "properties", force: :cascade do |t|
      t.string   "name",                 limit: 255
      t.integer  "landlord_id"
      t.integer  "manager_id"
    end

    create_table "addresses", force: :cascade do |t|
      t.string   "name",                 limit: 255
      t.boolean  "verified"
      t.integer  "property_id"
    end

    create_table "leases", force: :cascade do |t|
      t.integer  "property_id"
      t.integer  "tenant_id"
    end

    create_table "tenants", force: :cascade do |t|
      t.string   "name",                 limit: 255
    end

    create_table "tags", force: :cascade do |t|
      t.string   "name",                 limit: 255
      t.boolean  "featured"
    end

    create_table "properties_tags", id: false, force: :cascade do |t|
      t.integer  "property_id"
      t.integer  "tag_id"
    end
  end

  class Landlord < ActiveRecord::Base
    has_many :children, class_name: 'Landlord', foreign_key: :parent_id
  end

  class Address < ActiveRecord::Base
  end

  class Tenant < ActiveRecord::Base
  end

  class Lease < ActiveRecord::Base
    belongs_to :tenant
  end

  class Tag < ActiveRecord::Base
  end

  class Property < ActiveRecord::Base
    belongs_to :landlord
    belongs_to :manager, class_name: 'Landlord'
    has_many :addresses
    has_many :verified_addresses, -> { where(verified: true) }, class_name: 'Address'
    has_many :leases
    has_many :tenants, through: :leases
    has_and_belongs_to_many :tags, join_table: 'properties_tags'
    has_and_belongs_to_many :featured_tags, -> { where(featured: true) }, class_name: 'Tag', join_table: 'properties_tags'
  end

  # By landlord: one and three (Alice), then two (Zed). By manager: two
  # and three (Alice), then one (Zed). one and two tie on their smallest
  # address, but two has the larger verified one. Alice's child is Zara,
  # Zed's is Aaron. three has no addresses, tenants or tags.
  fixtures do
    alice = Landlord.create!(name: 'Alice')
    zed = Landlord.create!(name: 'Zed')
    Landlord.create!(name: 'Zara', parent_id: alice.id)
    Landlord.create!(name: 'Aaron', parent_id: zed.id)

    one = Property.create!(name: 'one', landlord: alice, manager: zed)
    two = Property.create!(name: 'two', landlord: zed, manager: alice)
    three = Property.create!(name: 'three', landlord: alice, manager: alice)

    Address.create!(property_id: one.id, name: 'a', verified: true)
    Address.create!(property_id: one.id, name: 'z', verified: false)
    Address.create!(property_id: two.id, name: 'a', verified: false)
    Address.create!(property_id: two.id, name: 'm', verified: true)

    mall = Tenant.create!(name: 'Mall')
    Lease.create!(property_id: one.id, tenant: mall)
    Lease.create!(property_id: one.id, tenant: Tenant.create!(name: 'Zoo'))
    Lease.create!(property_id: two.id, tenant: mall)
    Lease.create!(property_id: two.id, tenant: Tenant.create!(name: 'Apex'))

    one.tags = [Tag.create!(name: 'Apex', featured: false), Tag.create!(name: 'Zoo', featured: true)]
    two.tags = [Tag.create!(name: 'Mall', featured: true)]
  end

  def assert_sql(expected, query)
    assert_equal(expected.strip.gsub(/\s+/, ' '), query.to_sql.gsub(/\s+/, ' '))
  end

  test '::joins(:belongs_to_relationship).sort(:other_belongs_to_relationship_to_the_same_table => :column)' do
    query = Property.joins(:landlord).sort(manager: {name: :asc}, name: :asc)

    assert_sql(<<-SQL, query)
      SELECT "properties".* FROM "properties"
      INNER JOIN "landlords" ON "landlords"."id" = "properties"."landlord_id"
      LEFT OUTER JOIN "landlords" "managers_properties" ON "managers_properties"."id" = "properties"."manager_id"
      GROUP BY "properties"."id"
      ORDER BY MIN("managers_properties"."name") ASC, "properties"."name" ASC
    SQL

    assert_equal ['three', 'two', 'one'], query.map(&:name)
  end

  test '::sort(:belongs_to_relationship => :column, :other_belongs_to_relationship_to_the_same_table => :column)' do
    query = Property.sort(landlord: {name: :asc}, manager: {name: :desc})

    assert_sql(<<-SQL, query)
      SELECT "properties".* FROM "properties"
      LEFT OUTER JOIN "landlords" ON "landlords"."id" = "properties"."landlord_id"
      LEFT OUTER JOIN "landlords" "managers_properties" ON "managers_properties"."id" = "properties"."manager_id"
      GROUP BY "properties"."id"
      ORDER BY MIN("landlords"."name") ASC, MAX("managers_properties"."name") DESC
    SQL

    assert_equal ['one', 'three', 'two'], query.map(&:name)
  end

  # The two sorts' ORDER BY entries differ only in their table, so they
  # used to be deduplicated into one when both named the same table.
  test '::sort(:belongs_to_relationship => :column).sort(:other_belongs_to_relationship_to_the_same_table => :column)' do
    query = Property.sort(manager: :name).sort(landlord: :name)

    assert_sql(<<-SQL, query)
      SELECT "properties".* FROM "properties"
      LEFT OUTER JOIN "landlords" ON "landlords"."id" = "properties"."manager_id"
      LEFT OUTER JOIN "landlords" "landlords_properties" ON "landlords_properties"."id" = "properties"."landlord_id"
      GROUP BY "properties"."id"
      ORDER BY MIN("landlords"."name") ASC, MIN("landlords_properties"."name") ASC
    SQL

    assert_equal ['three', 'two', 'one'], query.map(&:name)
  end

  # Joins added after the sort can move the alias onto the sort's join.
  test '::sort(:belongs_to_relationship => :column).joins(:other_belongs_to_relationship_to_the_same_table)' do
    query = Property.sort(manager: {name: :desc}, name: :asc).joins(:landlord)

    assert_sql(<<-SQL, query)
      SELECT "properties".* FROM "properties"
      INNER JOIN "landlords" ON "landlords"."id" = "properties"."landlord_id"
      LEFT OUTER JOIN "landlords" "managers_properties" ON "managers_properties"."id" = "properties"."manager_id"
      GROUP BY "properties"."id"
      ORDER BY MAX("managers_properties"."name") DESC, "properties"."name" ASC
    SQL

    assert_equal ['one', 'three', 'two'], query.map(&:name)
    assert_equal ['two', 'three', 'one'], query.reverse_order.map(&:name)
  end

  test '::joins("...").sort(:belongs_to_relationship => :column) with the table already joined by a string' do
    query = Property.joins('INNER JOIN landlords ON landlords.id = properties.manager_id').sort(landlord: :name, name: :desc)

    assert_sql(<<-SQL, query)
      SELECT "properties".* FROM "properties"
      LEFT OUTER JOIN "landlords" "landlords_properties" ON "landlords_properties"."id" = "properties"."landlord_id"
      INNER JOIN landlords ON landlords.id = properties.manager_id
      GROUP BY "properties"."id"
      ORDER BY MIN("landlords_properties"."name") ASC, "properties"."name" DESC
    SQL

    assert_equal ['three', 'one', 'two'], query.map(&:name)
  end

  # The sort shares a join of the association the relation already has,
  # and repeated sorts on it share one join.
  test '::joins(:belongs_to_relationship).sort(:belongs_to_relationship => :column).sort(...)' do
    query = Property.joins(:manager).sort(manager: :name).sort(manager: {name: :desc})

    assert_sql(<<-SQL, query)
      SELECT "properties".* FROM "properties"
      INNER JOIN "landlords" ON "landlords"."id" = "properties"."manager_id"
      GROUP BY "properties"."id"
      ORDER BY MIN("landlords"."name") ASC, MAX("landlords"."name") DESC
    SQL
  end

  test '::sort(:has_many_relationship => :column, :scoped_has_many_relationship_to_the_same_table => :column)' do
    query = Property.sort(addresses: {name: :asc}, verified_addresses: {name: :desc})

    assert_sql(<<-SQL, query)
      SELECT "properties".* FROM "properties"
      LEFT OUTER JOIN "addresses" ON "addresses"."property_id" = "properties"."id"
      LEFT OUTER JOIN "addresses" "verified_addresses_properties" ON "verified_addresses_properties"."verified" = TRUE AND "verified_addresses_properties"."property_id" = "properties"."id"
      GROUP BY "properties"."id"
      ORDER BY MIN("addresses"."name") ASC, MAX("verified_addresses_properties"."name") DESC
    SQL

    assert_equal ['two', 'one', 'three'], query.map(&:name)
  end

  test '::sort(:self_referential_has_many_relationship => :column)' do
    query = Landlord.where(parent_id: nil).sort(children: :name)

    assert_sql(<<-SQL, query)
      SELECT "landlords".* FROM "landlords"
      LEFT OUTER JOIN "landlords" "children_landlords" ON "children_landlords"."parent_id" = "landlords"."id"
      WHERE "landlords"."parent_id" IS NULL
      GROUP BY "landlords"."id"
      ORDER BY MIN("children_landlords"."name") ASC
    SQL

    assert_equal ['Zed', 'Alice'], query.map(&:name)
  end

  # The caller's join is filtered to one tenant; the sort still sees all
  # of each property's tenants through its own join.
  test '::joins(:through => :target).where(...).sort(:has_many_through_relationship => :column)' do
    query = Property.joins(leases: :tenant).where(tenants: {name: 'Mall'}).sort(tenants: :name)

    assert_sql(<<-SQL, query)
      SELECT "properties".* FROM "properties"
      INNER JOIN "leases" ON "leases"."property_id" = "properties"."id"
      INNER JOIN "tenants" ON "tenants"."id" = "leases"."tenant_id"
      LEFT OUTER JOIN "leases" "leases_properties_join" ON "leases_properties_join"."property_id" = "properties"."id"
      LEFT OUTER JOIN "tenants" "tenants_properties" ON "tenants_properties"."id" = "leases_properties_join"."tenant_id"
      WHERE "tenants"."name" = 'Mall'
      GROUP BY "properties"."id"
      ORDER BY MIN("tenants_properties"."name") ASC
    SQL

    assert_equal ['two', 'one'], query.map(&:name)
  end

  test '::sort(:habtm_relationship => :column, :scoped_habtm_relationship_to_the_same_table => :column)' do
    query = Property.sort(tags: {name: :asc}, featured_tags: {name: {desc: :nulls_last}})

    assert_sql(<<-SQL, query)
      SELECT "properties".* FROM "properties"
      LEFT OUTER JOIN "properties_tags" ON "properties_tags"."property_id" = "properties"."id"
      LEFT OUTER JOIN "tags" ON "tags"."id" = "properties_tags"."tag_id"
      LEFT OUTER JOIN "properties_tags" "aliasedjoinsorttest_properties_featured_tags_properties_join" ON "aliasedjoinsorttest_properties_featured_tags_properties_join"."property_id" = "properties"."id"
      LEFT OUTER JOIN "tags" "featured_tags_properties" ON "featured_tags_properties"."featured" = TRUE AND "featured_tags_properties"."id" = "aliasedjoinsorttest_properties_featured_tags_properties_join"."tag_id"
      GROUP BY "properties"."id"
      ORDER BY MIN("tags"."name") ASC, MAX("featured_tags_properties"."name") DESC NULLS LAST
    SQL

    assert_equal ['one', 'two', 'three'], query.map(&:name)
    assert_equal ['two', 'one', 'three'], Property.sort(featured_tags: {name: :asc}, tags: :name).map(&:name)
  end

  # Without the sort's join there is no table to order by; raise rather
  # than order by whatever else has the table's name.
  test '::sort(:relationship => :column) without the join raises' do
    query = Property.joins(:landlord).sort(manager: :name).unscope(:left_outer_joins)

    assert_raises(ActiveRecord::Sort::InvalidSort) { query.to_sql }
  end

end
