require 'simplecov'
SimpleCov.start

# To make testing/debugging easier, test within this source tree versus an
# installed gem
$LOAD_PATH << File.expand_path('../lib', __FILE__)

require "minitest/autorun"
require 'minitest/unit'
require 'minitest/reporters'
require 'factory_bot'
require 'sunstone'
require 'active_record/sort'
require 'faker'
require 'webmock'

WebMock.enable!
WebMock.disable_net_connect!

FactoryBot.find_definitions

# Setup the test db
ActiveSupport.test_order = :random
require File.expand_path('../database', __FILE__)

Minitest::Reporters.use! Minitest::Reporters::SpecReporter.new

class ActiveSupport::TestCase
  include ActiveRecord::TestFixtures
  include FactoryBot::Syntax::Methods
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

end
