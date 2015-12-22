require 'active_record'

require File.expand_path(File.join(__FILE__, '../../../ext/arel/order_predications'))
require File.expand_path(File.join(__FILE__, '../../../ext/arel/nodes/ascending'))
require File.expand_path(File.join(__FILE__, '../../../ext/arel/nodes/descending'))
require File.expand_path(File.join(__FILE__, '../../../ext/arel/visitors/postgresql'))
require File.expand_path(File.join(__FILE__, '../../../ext/active_record/base'))

ActiveRecord::Querying.delegate :sort, to: :all