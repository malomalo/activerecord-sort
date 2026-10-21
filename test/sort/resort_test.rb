require 'test_helper'

class ResortTest < ActiveSupport::TestCase

  schema do
    create_table "addresses", force: :cascade do |t|
      t.string   "name"
      t.integer  "property_id"
    end

    create_table "properties", force: :cascade do |t|
      t.string   "name",                 limit: 255
    end
  end

  class Address < ActiveRecord::Base
    belongs_to :property
  end

  class Property < ActiveRecord::Base
    has_many :addresses, -> { order(:name) }
  end

  test '#resort replaces an existing order' do
    assert_equal('SELECT "properties".* FROM "properties" ORDER BY "properties"."id" ASC', Property.order(:name).resort(:id).to_sql.gsub(/\s+/, ' '))
  end

  test '#sort adds to an existing order' do
    assert_equal('SELECT "properties".* FROM "properties" ORDER BY "properties"."name" ASC, "properties"."id" ASC', Property.order(:name).sort(:id).to_sql.gsub(/\s+/, ' '))
  end

  test '::resort(:column => :desc)' do
    assert_equal('SELECT "properties".* FROM "properties" ORDER BY "properties"."id" DESC', Property.resort(id: :desc).to_sql.gsub(/\s+/, ' '))
  end

  test '#resort replaces the order of an association scope' do
    property = Property.create!(name: 'a')
    b = property.addresses.create!(name: 'b')
    a = property.addresses.create!(name: 'a')

    assert_equal [a, b], property.addresses.to_a
    assert_equal [b, a], property.addresses.resort(:id).to_a
    assert_no_match(/"addresses"\."name"/, property.addresses.resort(:id).to_sql)
  end

  test '#resort with a relation replaces an existing order' do
    assert_equal(<<-SQL.strip.gsub(/\s+/, ' '), Property.order(:name).resort(addresses: :id).to_sql.gsub(/\s+/, ' '))
      SELECT "properties".* FROM "properties"
      LEFT OUTER JOIN "addresses" ON "addresses"."property_id" = "properties"."id"
      GROUP BY "properties"."id"
      ORDER BY MIN("addresses"."id") ASC
    SQL
  end

  test '#resort with no ordering removes the order' do
    assert_equal('SELECT "properties".* FROM "properties"', Property.order(:name).resort.to_sql)
    assert_equal('SELECT "properties".* FROM "properties"', Property.order(:name).resort(nil).to_sql)
    assert_equal('SELECT "properties".* FROM "properties"', Property.order(:name).resort([]).to_sql)
  end

  test '#resort raises InvalidSort like #sort' do
    assert_raises(ActiveRecord::Sort::InvalidSort) { Property.order(:name).resort(:nonexistent) }
  end

end
