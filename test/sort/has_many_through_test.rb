require 'test_helper'

class HasManyThroughSortTest < ActiveSupport::TestCase

  schema do
    create_table "properties", force: :cascade do |t|
      t.string   "name",                 limit: 255
    end

    create_table "leases", force: :cascade do |t|
      t.integer  "property_id"
      t.integer  "tenant_id"
    end

    create_table "tenants", force: :cascade do |t|
      t.string   "name",                 limit: 255
    end
  end

  class Tenant < ActiveRecord::Base
  end

  class Lease < ActiveRecord::Base
    belongs_to :property
    belongs_to :tenant
  end

  class Property < ActiveRecord::Base
    has_many :leases
    has_many :tenants, through: :leases
  end

  # multi sorts first ascending by tenant name (Apex < Mall) and first
  # descending too (Zoo > Mall); vacant has no tenants at all.
  fixtures do
    Property.create!(name: 'multi', tenants: [Tenant.create!(name: 'Zoo'), Tenant.create!(name: 'Apex')])
    Property.create!(name: 'single', tenants: [Tenant.create!(name: 'Mall')])
    Property.create!(name: 'vacant')
  end

  test '::sort(:has_many_through_relationship => :column)' do
    query = Property.sort(tenants: :name)

    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.gsub(/\s+/, ' '))
      SELECT "properties".* FROM "properties"
      LEFT OUTER JOIN "leases" ON "leases"."property_id" = "properties"."id"
      LEFT OUTER JOIN "tenants" ON "tenants"."id" = "leases"."tenant_id"
      GROUP BY "properties"."id"
      ORDER BY MIN("tenants"."name") ASC
    SQL

    assert_equal ['multi', 'single', 'vacant'], query.map(&:name)
  end

  test '::sort(:has_many_through_relationship => {:column => :desc})' do
    query = Property.sort(tenants: {name: :desc})

    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.gsub(/\s+/, ' '))
      SELECT "properties".* FROM "properties"
      LEFT OUTER JOIN "leases" ON "leases"."property_id" = "properties"."id"
      LEFT OUTER JOIN "tenants" ON "tenants"."id" = "leases"."tenant_id"
      GROUP BY "properties"."id"
      ORDER BY MAX("tenants"."name") DESC
    SQL

    assert_equal ['vacant', 'multi', 'single'], query.map(&:name)
  end

  test '::sort(:has_many_through_relationship => {:column => {:desc => :nulls_last}})' do
    query = Property.sort(tenants: {name: {desc: :nulls_last}})

    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.gsub(/\s+/, ' '))
      SELECT "properties".* FROM "properties"
      LEFT OUTER JOIN "leases" ON "leases"."property_id" = "properties"."id"
      LEFT OUTER JOIN "tenants" ON "tenants"."id" = "leases"."tenant_id"
      GROUP BY "properties"."id"
      ORDER BY MAX("tenants"."name") DESC NULLS LAST
    SQL

    assert_equal ['multi', 'single', 'vacant'], query.map(&:name)
  end

  test '::sort(:has_many_through_relationship => :column) returns each record once despite multiple members' do
    names = Property.sort(tenants: {name: :asc}).map(&:name)

    assert_equal names.uniq, names
    assert_equal ['multi', 'single', 'vacant'], names
  end

  test '::sort(:has_many_through_relationship => :column).count returns the record count' do
    assert_equal 3, Property.sort(tenants: {name: :asc}).count
  end

end
