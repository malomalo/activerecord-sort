require 'simplecov'
SimpleCov.start do
  skip "/test/"
  skip "/lib/active_record/sort/version"
  cover "{ext,lib}/**/*.rb"
  enable_coverage :branch
  # disable_coverage :line
end

# To make testing/debugging easier, test within this source tree versus an
# installed gem
$LOAD_PATH << File.expand_path('../lib', __FILE__)

require "minitest/autorun"
require 'minitest/reporters'
require 'sunstone'
require 'active_record/sort'
require 'faker'
require 'webmock'
require 'debug'

# sunstone's predicate_builder patch calls TableMetadata#associated_with?,
# which ActiveRecord 8.1 renamed to #associated_with — without the alias any
# nested-hash where (e.g. HABTM writes and preloads) raises NoMethodError.
if !ActiveRecord::TableMetadata.method_defined?(:associated_with?) &&
    ActiveRecord::TableMetadata.method_defined?(:associated_with)
  ActiveRecord::TableMetadata.send(:alias_method, :associated_with?, :associated_with)
end

WebMock.enable!
WebMock.disable_net_connect!

ActiveSupport.test_order = :random

Minitest::Reporters.use! Minitest::Reporters::SpecReporter.new

class ActiveSupport::TestCase
  include WebMock::API

  def deep_transform_query(object)
    case object
    when Hash
      object.each_with_object({}) do |(key, value), result|
        result[key.to_s] = deep_transform_query(value)
      end
    when Array
      object.map {|e| deep_transform_query(e) }
    when Symbol
      object.to_s
    else
      object
    end
  end

  def unpack(data)
    MessagePack.unpack(CGI::unescape(data))
  end

  def webmock(method, path, query=nil)
    query = deep_transform_query(query) if query

    stub_request(method, /^#{SunstoneRecord.connection.instance_variable_get(:@connection).url}/).with do |req|
      if query
        if req&.uri&.path == path && req.uri.query
          puts unpack(req.uri.query.sub(/=true$/, '')).inspect
        end
        req&.uri&.path == path && req.uri.query && unpack(req.uri.query.sub(/=true$/, '')) == query
      else
        req&.uri&.path == path && req.uri.query.nil?
      end
    end
  end

  def setup
      sunstone_schema = {
        points: {
          columns: {
            id: { type: :integer, primary_key: true, null: false, array: false },
            line_id: { type: :integer, primary_key: false, null: true, array: false }
          }
        },
        lines: {
          columns: {
            id: { type: :integer, primary_key: true, null: false, array: false }
          }
        }
      }

      req_stub = stub_request(:get, /^http:\/\/example.com/).with do |req|
        case req.uri.path
        when '/tables'
          true
        when /^\/\w+\/schema$/i
          true
        else
          false
        end
      end

      req_stub.to_return do |req|
        case req.uri.path
        when '/tables'
          {
            body: sunstone_schema.keys.to_json,
            headers: { 'StandardAPI-Version' => '5.0.0.5' }
          }
        when /^\/(\w+)\/schema$/i
          {
            body: sunstone_schema[$1.to_sym].to_json,
            headers: { 'StandardAPI-Version' => '5.0.0.5' }
          }
        end
      end
  end


  ## Setup Schema per test suite
  def self.schema(&block)
    self.class_variable_set(:@@schema, block)
  end

  set_callback(:setup, :before) do
    if !self.class.class_variable_defined?(:@@suite_setup_run) && self.class.class_variable_defined?(:@@schema)
      ActiveRecord::Base.establish_connection({
        adapter:  "postgresql",
        database: "activerecord-sort-test",
        encoding: "utf8"
      })

      db_config = ActiveRecord::Base.connection_db_config
      db_tasks = ActiveRecord::Tasks::PostgreSQLDatabaseTasks.new(db_config)
      db_tasks.purge

      ActiveRecord::Migration.suppress_messages do
        ActiveRecord::Schema.define(&self.class.class_variable_get(:@@schema))
        ActiveRecord::Migration.execute("SELECT c.relname FROM pg_class c WHERE c.relkind = 'S'").each_row do |row|
          ActiveRecord::Migration.execute("ALTER SEQUENCE #{row[0]} RESTART WITH #{rand(1..50_000)}")
          # "INSERT INTO SQLITE_SEQUENCE (name,seq) VALUES ('#{table}', #{rand(50_000)})" for sqlite
        end
      end
    else
      connection = ActiveRecord::Base.connection
      tables = connection.tables - %w[schema_migrations ar_internal_metadata]
      connection.execute("TRUNCATE #{tables.map { |t| connection.quote_table_name(t) }.join(', ')} CONTINUE IDENTITY CASCADE")
    end
    self.class.class_variable_set(:@@suite_setup_run, true)
  end
  
end
