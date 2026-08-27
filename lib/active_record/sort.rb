require 'active_record'
require 'arel/extensions'

require File.expand_path(File.join(__FILE__, '../../../ext/active_record/base'))

ActiveRecord::QueryMethods.prepend(ActiveRecord::Sort)
ActiveRecord::Querying.delegate :sort, to: :all