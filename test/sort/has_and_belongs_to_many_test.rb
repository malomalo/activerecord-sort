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
  
  test '::sort(:habtm_relationship => :column)' do
    query = Property.sort(:tags => :name)

    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.gsub(/\s+/, ' '))
      SELECT "properties".*, MIN("tags"."name") AS ar_sort_0 FROM "properties"
      LEFT OUTER JOIN "properties_tags" ON "properties_tags"."property_id" = "properties"."id"
      LEFT OUTER JOIN "tags" ON "tags"."id" = "properties_tags"."tag_id"
      GROUP BY "properties"."id"
      ORDER BY ar_sort_0 ASC
    SQL
  end

  test '::sort(:habtm_relationship => {:column => :desc})' do
    query = Property.sort(:tags => {:name => :desc})

    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.gsub(/\s+/, ' '))
      SELECT "properties".*, MIN("tags"."name") AS ar_sort_0 FROM "properties"
      LEFT OUTER JOIN "properties_tags" ON "properties_tags"."property_id" = "properties"."id"
      LEFT OUTER JOIN "tags" ON "tags"."id" = "properties_tags"."tag_id"
      GROUP BY "properties"."id"
      ORDER BY ar_sort_0 DESC
    SQL
  end

  test '::sort(:habtm_relationship => {:column => {:desc => :nulls_last}})' do
    query = Property.sort(:tags => {:name => {:desc => :nulls_last}})

    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.gsub(/\s+/, ' '))
      SELECT "properties".*, MIN("tags"."name") AS ar_sort_0 FROM "properties"
      LEFT OUTER JOIN "properties_tags" ON "properties_tags"."property_id" = "properties"."id"
      LEFT OUTER JOIN "tags" ON "tags"."id" = "properties_tags"."tag_id"
      GROUP BY "properties"."id"
      ORDER BY ar_sort_0 DESC NULLS LAST
    SQL
  end

  test '::sort(:habtm_relationship => :column) sorts by first member and keeps empty collections' do
    Property.create!(name: 'multi', tags: [Tag.create!(name: 'Zoo'), Tag.create!(name: 'Apex')])
    Property.create!(name: 'single', tags: [Tag.create!(name: 'Mall')])
    Property.create!(name: 'untagged')

    assert_equal ['multi', 'single', 'untagged'], Property.sort(:tags => {:name => {:asc => :nulls_last}}).map(&:name)
    assert_equal ['single', 'multi', 'untagged'], Property.sort(:tags => {:name => {:desc => :nulls_last}}).map(&:name)
  end

  test '::sort(:habtm_relationship => :column) returns each record once despite multiple members' do
    Property.create!(name: 'multi', tags: [Tag.create!(name: 'Zoo'), Tag.create!(name: 'Apex')])
    Property.create!(name: 'single', tags: [Tag.create!(name: 'Mall')])

    names = Property.sort(:tags => {:name => :asc}).map(&:name)
    assert_equal names.uniq, names
    assert_equal ['multi', 'single'], names
  end

  test '::includes(:habtm_relationship).sort(:habtm_relationship => :column) returns each record once and preloads' do
    Property.create!(name: 'multi', tags: [Tag.create!(name: 'Zoo'), Tag.create!(name: 'Apex')])
    Property.create!(name: 'single', tags: [Tag.create!(name: 'Mall')])

    records = Property.includes(:tags).sort(:tags => {:name => :asc}).to_a

    names = records.map(&:name)
    assert_equal names.uniq, names
    assert_equal ['multi', 'single'], names

    assert records.all? { |record| record.association(:tags).loaded? }
    assert_equal ['Apex', 'Zoo'], records.first.tags.map(&:name).sort
  end

end
