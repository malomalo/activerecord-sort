require 'active_record'
require 'arel/extensions'

require File.expand_path(File.join(__FILE__, '../../../ext/active_record/base'))

module ActiveRecord::Sort

  def inherited(subclass)
    super
    subclass.instance_variable_set('@sorts', HashWithIndifferentAccess.new)
  end

  def sorts
    @sorts ||= HashWithIndifferentAccess.new
  end

  def sort_on(name, dependent_joins = nil, &block)
    sorts[name.to_s] = { joins: dependent_joins, block: block }
  end

end

ActiveRecord::Base.extend(ActiveRecord::Sort)
ActiveRecord::Querying.delegate :sort, to: :all