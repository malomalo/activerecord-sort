require 'test_helper'

class HasAndBelongsToManySortTest < ActiveSupport::TestCase

  schema do
    create_table "properties", force: :cascade do |t|
      t.string   "name",                 limit: 255
    end

    create_table "properties_tags", id: false, force: :cascade do |t|
      t.integer  "property_id"
      t.integer  "tag_id"
    end

    create_table "tags", force: :cascade do |t|
      t.string   "name",                 limit: 255
    end
  end

  class Tag < ActiveRecord::Base
    has_and_belongs_to_many :properties
  end

  class Property < ActiveRecord::Base
    has_and_belongs_to_many :tags
  end

  # multi sorts first by tag name (Apex < Mall) despite also having the
  # last tag (Zoo); untagged has no tags at all.
  fixtures do
    Property.create!(name: 'multi', tags: [Tag.create!(name: 'Zoo'), Tag.create!(name: 'Apex')])
    Property.create!(name: 'single', tags: [Tag.create!(name: 'Mall')])
    Property.create!(name: 'untagged')
  end

  test '::sort(:habtm_relationship => :column)' do
    query = Property.sort(tags: :name)

    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.gsub(/\s+/, ' '))
      SELECT "properties".* FROM "properties"
      LEFT OUTER JOIN "properties_tags" ON "properties_tags"."property_id" = "properties"."id"
      LEFT OUTER JOIN "tags" ON "tags"."id" = "properties_tags"."tag_id"
      GROUP BY "properties"."id"
      ORDER BY MIN("tags"."name") ASC
    SQL

    assert_equal ['multi', 'single', 'untagged'], query.map(&:name)
  end

  test '::sort(:habtm_relationship => {:column => :desc})' do
    query = Property.sort(tags: {name: :desc})

    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.gsub(/\s+/, ' '))
      SELECT "properties".* FROM "properties"
      LEFT OUTER JOIN "properties_tags" ON "properties_tags"."property_id" = "properties"."id"
      LEFT OUTER JOIN "tags" ON "tags"."id" = "properties_tags"."tag_id"
      GROUP BY "properties"."id"
      ORDER BY MAX("tags"."name") DESC
    SQL

    assert_equal ['untagged', 'multi', 'single'], query.map(&:name)
  end

  test '::sort(:habtm_relationship => {:column => {:desc => :nulls_last}})' do
    query = Property.sort(tags: {name: {desc: :nulls_last}})

    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.gsub(/\s+/, ' '))
      SELECT "properties".* FROM "properties"
      LEFT OUTER JOIN "properties_tags" ON "properties_tags"."property_id" = "properties"."id"
      LEFT OUTER JOIN "tags" ON "tags"."id" = "properties_tags"."tag_id"
      GROUP BY "properties"."id"
      ORDER BY MAX("tags"."name") DESC NULLS LAST
    SQL

    assert_equal ['multi', 'single', 'untagged'], query.map(&:name)
  end

  test '::sort(:habtm_relationship => {:column => :invalid}) raises' do
    assert_raises(ActiveRecord::StatementInvalid) do
      Property.sort(tags: {name: :invalid})
    end
  end

  test '::sort(:habtm_relationship => :unknown_column) raises' do
    assert_raises(ActiveRecord::StatementInvalid) do
      Property.sort(tags: :not_a_column)
    end
  end

  # pluck/ids replace the select list — the ORDER BY references the
  # aggregate expression directly (nothing in the select list), so the
  # sort survives that.
  test '::sort(:habtm_relationship => :column) keeps the sort when the select list is replaced (pluck, ids)' do
    expected_ids = ['multi', 'single', 'untagged'].map { |name| Property.find_by!(name: name).id }

    assert_equal expected_ids, Property.sort(tags: {name: :asc}).pluck(:id)
    assert_equal expected_ids, Property.sort(tags: {name: :asc}).ids
  end

  # Ascending keys each record by its smallest member, descending by its
  # largest — multi holds both extremes (Apex and Zoo), so it sorts first
  # in both directions.
  test '::sort(:habtm_relationship => :column) sorts asc by first member, desc by last member, and keeps empty collections' do
    assert_equal ['multi', 'single', 'untagged'], Property.sort(tags: {name: {asc: :nulls_last}}).map(&:name)
    assert_equal ['multi', 'single', 'untagged'], Property.sort(tags: {name: {desc: :nulls_last}}).map(&:name)
  end

  test '::sort(:habtm_relationship => :column) returns each record once despite multiple members' do
    names = Property.sort(tags: {name: :asc}).map(&:name)

    assert_equal names.uniq, names
    assert_equal ['multi', 'single', 'untagged'], names
  end

  test '::includes(:habtm_relationship).sort(:habtm_relationship => :column) returns each record once and preloads' do
    records = Property.includes(:tags).sort(tags: {name: :asc}).to_a

    names = records.map(&:name)
    assert_equal names.uniq, names
    assert_equal ['multi', 'single', 'untagged'], names

    assert records.all? { |record| record.association(:tags).loaded? }
    assert_equal ['Apex', 'Zoo'], records.first.tags.map(&:name).sort
  end

end
