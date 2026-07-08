require 'test_helper'

class SortRelationTest < ActiveSupport::TestCase

  test '::sort(:has_many_relationship => :column)' do
    query = Property.sort(:addresses => :id)

    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.gsub(/\s+/, ' '))
      SELECT "properties".*, "addresses"."id" FROM "properties"
      INNER JOIN "addresses" ON "addresses"."property_id" = "properties"."id"
      ORDER BY "addresses"."id" ASC
    SQL
  end

  test '::sort(:has_many_relationship => {:column => :desc})' do
    query = Property.sort(:addresses => {:id => :desc})

    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.gsub(/\s+/, ' '))
      SELECT "properties".*, "addresses"."id" FROM "properties"
      INNER JOIN "addresses" ON "addresses"."property_id" = "properties"."id"
      ORDER BY "addresses"."id" DESC
    SQL
  end

  test '::sort(:has_many_relationship => {:column => {:asc => :nulls_first}})' do
    query = Property.sort(:addresses => {:id => {:asc => :nulls_first}})

    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.gsub(/\s+/, ' '))
      SELECT "properties".*, "addresses"."id" FROM "properties"
      INNER JOIN "addresses" ON "addresses"."property_id" = "properties"."id"
      ORDER BY "addresses"."id" ASC NULLS FIRST
    SQL
  end

  test '::sort(:has_many_relationship => {:column => {:desc => :nulls_last}})' do
    query = Property.sort(:addresses => {:id => {:desc => :nulls_last}})

    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.gsub(/\s+/, ' '))
      SELECT "properties".*, "addresses"."id" FROM "properties"
      INNER JOIN "addresses" ON "addresses"."property_id" = "properties"."id"
      ORDER BY "addresses"."id" DESC NULLS LAST
    SQL
  end

  test '::sort(:habtm_relationship => :column)' do
    query = Property.sort(:tags => :name)

    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.gsub(/\s+/, ' '))
      SELECT "properties".*, MIN("tags"."name") AS min_tags_name FROM "properties"
      LEFT OUTER JOIN "properties_tags" ON "properties_tags"."property_id" = "properties"."id"
      LEFT OUTER JOIN "tags" ON "tags"."id" = "properties_tags"."tag_id"
      GROUP BY "properties"."id"
      ORDER BY min_tags_name ASC
    SQL
  end

  test '::sort(:habtm_relationship => {:column => :desc})' do
    query = Property.sort(:tags => {:name => :desc})

    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.gsub(/\s+/, ' '))
      SELECT "properties".*, MIN("tags"."name") AS min_tags_name FROM "properties"
      LEFT OUTER JOIN "properties_tags" ON "properties_tags"."property_id" = "properties"."id"
      LEFT OUTER JOIN "tags" ON "tags"."id" = "properties_tags"."tag_id"
      GROUP BY "properties"."id"
      ORDER BY min_tags_name DESC
    SQL
  end

  test '::sort(:habtm_relationship => {:column => {:desc => :nulls_last}})' do
    query = Property.sort(:tags => {:name => {:desc => :nulls_last}})

    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.gsub(/\s+/, ' '))
      SELECT "properties".*, MIN("tags"."name") AS min_tags_name FROM "properties"
      LEFT OUTER JOIN "properties_tags" ON "properties_tags"."property_id" = "properties"."id"
      LEFT OUTER JOIN "tags" ON "tags"."id" = "properties_tags"."tag_id"
      GROUP BY "properties"."id"
      ORDER BY min_tags_name DESC NULLS LAST
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

  test '::sort(:belongs_to_relationship => {:column => :desc})' do
    query = Address.sort(:property => {:id => :desc})

    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.gsub(/\s+/, ' '))
      SELECT "addresses".*, "properties"."id" FROM "addresses"
      LEFT OUTER JOIN "properties" ON "properties"."id" = "addresses"."property_id"
      ORDER BY "properties"."id" DESC
    SQL
  end
  
  test '::sort(:belongs_to_relationship => {:column => :desc}).distinct_on' do
    query = Address.sort(:property => {:id => :desc}).distinct_on(:id)

    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), query.to_sql.gsub(/\s+/, ' '))
      SELECT DISTINCT ON ( "addresses"."id" ) "addresses".*, "properties"."id" FROM "addresses"
      LEFT OUTER JOIN "properties" ON "properties"."id" = "addresses"."property_id"
      ORDER BY "properties"."id" DESC
    SQL
  end

  # test 'SunstoneRecord::sort(:belongs_to_relationship => {:column => :desc})' do
  #   webmock(:get, "/points", limit: 1, order: [{lines: {id: :desc}}]).to_return({
  #     body: [{id: 42}].to_json
  #   })

  #   assert_equal 42, Point.sort(:line => {:id => :desc}).first.id
  # end


end
