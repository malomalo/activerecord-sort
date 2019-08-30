require 'simplecov'
SimpleCov.start

# To make testing/debugging easier, test within this source tree versus an
# installed gem
$LOAD_PATH << File.expand_path('../lib', __FILE__)

require "minitest/autorun"
require 'minitest/unit'
require 'minitest/reporters'
require 'factory_bot'
require 'active_record/sort'
require 'faker'

FactoryBot.find_definitions

# Setup the test db
ActiveSupport.test_order = :random
require File.expand_path('../database', __FILE__)

Minitest::Reporters.use! Minitest::Reporters::SpecReporter.new

class ActiveSupport::TestCase
  include ActiveRecord::TestFixtures
  include FactoryBot::Syntax::Methods
end
