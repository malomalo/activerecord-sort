require 'test_helper'

class MixedSortTest < ActiveSupport::TestCase

  schema do
    create_table "landlords", force: :cascade do |t|
      t.string   "name",                 limit: 255
    end

    create_table "properties", force: :cascade do |t|
      t.string   "name",                 limit: 255
      t.integer  "landlord_id"
    end

    create_table "addresses", force: :cascade do |t|
      t.integer  "name"
      t.integer  "property_id"
    end

    create_table "deeds", force: :cascade do |t|
      t.string   "name",                 limit: 255
      t.integer  "property_id"
    end

    create_table "tags", force: :cascade do |t|
      t.string   "name",                 limit: 255
    end

    create_table "properties_tags", id: false, force: :cascade do |t|
      t.integer  "property_id"
      t.integer  "tag_id"
    end
  end

  class Landlord < ActiveRecord::Base
  end

  class Address < ActiveRecord::Base
    belongs_to :property
  end

  class Deed < ActiveRecord::Base
    belongs_to :property
  end

  class Tag < ActiveRecord::Base
  end

  class Property < ActiveRecord::Base
    belongs_to :landlord
    has_many :addresses
    has_one :deed
    has_and_belongs_to_many :tags
  end

  # zebra sorts first by tag (Apex < Mall), acorn sorts first by name,
  # deed, and landlord.
  fixtures do
    zebra = Property.create!(
      name: 'zebra',
      landlord: Landlord.create!(name: 'Kate'),
      deed: Deed.create!(name: 'B-Deed'),
      tags: [Tag.create!(name: 'Apex')]
    )
    acorn = Property.create!(
      name: 'acorn',
      landlord: Landlord.create!(name: 'Larry'),
      deed: Deed.create!(name: 'A-Deed'),
      tags: [Tag.create!(name: 'Mall')]
    )
    zebra.addresses.create!(name: 1)
    zebra.addresses.create!(name: 2)
    acorn.addresses.create!(name: 3)
  end

  test '::sort mixing column, has_many, has_one, and belongs_to (no habtm)' do
    names = Property.sort(:name, addresses: {name: :asc}, deed: {name: :asc}, landlord: {name: :asc}).map(&:name)
    assert_equal ['acorn', 'zebra'], names
  end

  test '::sort mixing column and habtm' do
    names = Property.sort(:name, tags: {name: :asc}).map(&:name)
    assert_equal ['acorn', 'zebra'], names
  end

  test '::sort mixing habtm and belongs_to' do
    names = Property.sort(tags: {name: :asc}, landlord: {name: :asc}).map(&:name)
    assert_equal ['zebra', 'acorn'], names
  end

  test '::sort mixing habtm and has_one' do
    names = Property.sort(tags: {name: :asc}, deed: {name: :asc}).map(&:name)
    assert_equal ['zebra', 'acorn'], names
  end

  test '::sort mixing habtm and has_many' do
    names = Property.sort(tags: {name: :asc}, addresses: {name: :asc}).map(&:name)
    assert_equal ['zebra', 'acorn'], names
  end

  # Chained sorts accumulate ORDER BY entries but share a single GROUP BY:
  # each relation sort adds the primary-key grouping only if it isn't
  # already present, so repeated grouping collapses to one entry.
  test '::sort(...).sort(...) chained sorts share one GROUP BY' do
    query = Property.sort(tags: {name: :asc}).sort(deed: {name: :desc})

    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.gsub(/\s+/, ' '))
      SELECT "properties".* FROM "properties"
      LEFT OUTER JOIN "properties_tags" ON "properties_tags"."property_id" = "properties"."id"
      LEFT OUTER JOIN "tags" ON "tags"."id" = "properties_tags"."tag_id"
      LEFT OUTER JOIN "deeds" ON "deeds"."property_id" = "properties"."id"
      GROUP BY "properties"."id"
      ORDER BY MIN("tags"."name") ASC, MAX("deeds"."name") DESC
    SQL

    assert_equal ['zebra', 'acorn'], query.map(&:name)
  end

  test '::sort mixing all types of sorts' do
    names = Property.sort(:name, tags: {name: :asc}, addresses: {name: :asc}, deed: {name: :asc}, landlord: {name: :asc}).map(&:name)
    assert_equal ['acorn', 'zebra'], names
  end

  # Two relation sorts each append a GROUP BY on the primary key; they
  # collapse to one, so the aggregate override still sees group_values ==
  # [pk] and count returns the record count (2) rather than a per-group
  # Hash or a total inflated by the tag/address join fan-out.
  test '::sort mixing multiple relations counts each record once' do
    assert_equal 2, Property.sort(tags: {name: :asc}, addresses: {name: :asc}).count
  end

end
