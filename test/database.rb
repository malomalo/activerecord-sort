ActiveRecord::Base.establish_connection({
  adapter:  "postgresql",
  database: "activerecord-sort-test",
  encoding: "utf8"
})

db_config = ActiveRecord::Base.connection_db_config
task = ActiveRecord::Tasks::PostgreSQLDatabaseTasks.new(db_config)
task.drop
task.create

ActiveRecord::Migration.suppress_messages do
  ActiveRecord::Schema.define do

    create_table "addresses", force: :cascade do |t|
      t.integer  "name"
      t.integer  "property_id"
    end

    create_table "properties", force: :cascade do |t|
      t.string   "name",                 limit: 255
    end

    create_table "tags", force: :cascade do |t|
      t.string   "name",                 limit: 255
    end

    create_table "properties_tags", id: false, force: :cascade do |t|
      t.integer  "property_id"
      t.integer  "tag_id"
    end

  end
end

class Address < ActiveRecord::Base

  belongs_to :property

end

class Tag < ActiveRecord::Base

  has_and_belongs_to_many :properties

end

class Property < ActiveRecord::Base

  has_many :addresses
  has_and_belongs_to_many :tags

end



class SunstoneRecord < ActiveRecord::Base
  self.abstract_class = true
end

class Point < SunstoneRecord
  belongs_to :line
end

class Line < SunstoneRecord
  has_many :points
end

SunstoneRecord.establish_connection({
  adapter: 'sunstone',
  url: 'http://example.com'
})
