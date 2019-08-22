require 'active_record'
require 'active_record/relation'

module ActiveRecord
  module QueryMethods
  # class << self

    # ordering:
    # :id
    # :name, :id
    # :id => :desc
    # :id => {:desc => :nulls_last}
    # :listings => :id
    # :listings => {:id => {:asc => :nulls_first}}
    # :random
    def sort(*ordering)
      resource = all
      ordering.compact!
      ordering.flatten!
      return resource if ordering.size == 0
      
      ordering.each do |order|
        order = Array(order)

        order.each do |column_or_relation, options|
          if column_or_relation.to_sym == :random
            resource = resource.random_sort
          elsif self.column_names.include?(column_or_relation.to_s)
            resource = resource.sort_for_column(column_or_relation, options)
          elsif reflect_on_association(column_or_relation.to_sym)
            resource = resource.select(resource.klass.arel_table[Arel::Nodes::SqlLiteral.new('*')])
            resource = resource.sort_for_relation(column_or_relation.to_sym, options)
          else
            raise ActiveRecord::StatementInvalid.new("Unkown column #{column_or_relation}")
          end
        end
      end

      resource
    end
    
    def random_sort
      self.order(Arel::Nodes::RandomOrdering.new)
    end

    # TODO: probably don't need to cast to sym
    def sort_for_column(column, options)
      column = self.arel_table[column.to_s.underscore]
      direction = (options.is_a?(Hash) || options.is_a?(ActionController::Parameters) ? options.keys.first.to_sym : options.to_s.downcase.to_sym)

      nulls = (options.is_a?(Hash) ? options.values.first.to_sym : nil)
      if direction == :desc
        self.order(Arel::Nodes::Descending.new(column, nulls))
      elsif direction == :asc || direction == :''
        self.order(Arel::Nodes::Ascending.new(column, nulls))
      else
        raise ActiveRecord::StatementInvalid.new("Unkown ordering #{direction}")
      end
    end

    def sort_for_relation(relation, options)
      resource = self
      relation = reflect_on_association(relation)

      if relation.macro == :has_many
        options = [options] if !options.is_a?(Array)

        options.each do |order|
          order = Array(order)
          order.each do |column, options|
            column = relation.klass.arel_table[column]
            direction = (options.is_a?(Hash) ? options.keys.first.to_sym : options.to_s.downcase.to_sym)

            nulls = (options.is_a?(Hash) ? options.values.first.to_sym : nil)
            if direction == :desc
              # aggregation = Arel::Nodes::Max.new([column], "max_#{relation.name}_#{column.name}")
              # order = Arel::Nodes::Descending.new(Arel::Nodes::SqlLiteral.new("max_#{relation.name}_#{column.name}"), nulls)

              if relation.options[:through]
                resource = resource.joins(relation.options[:through] => relation.source_reflection_name)
              else
                resource = resource.joins(relation.name)
              end
              # resource = resource.select(aggregation)
              # resource = resource.order(order)
              resource = resource.order(Arel::Nodes::Descending.new(column, nulls))
            else
              # aggregation = Arel::Nodes::Min.new([column], "min_#{relation.name}_#{column.name}")
              order = Arel::Nodes::Ascending.new(Arel::Nodes::SqlLiteral.new("min_#{relation.name}_#{column.name}"), nulls)

              resource = resource.joins(relation.name)
              # resource = resource.select(aggregation)
              # resource = resource.order(order)
              resource = resource.order(Arel::Nodes::Ascending.new(column, nulls))
            end
          end
        end
      elsif relation.macro == :belongs_to || relation.macro == :has_one
        options = [options] if !options.is_a?(Array)

        options.each do |order|
          order = Array(order)
          order.each do |column, options|
            column = relation.klass.arel_table[column]
            direction = (options.is_a?(Hash) ? options.keys.first.to_sym : options.to_s.downcase.to_sym)

            nulls = (options.is_a?(Hash) ? options.values.first.to_sym : nil)
            if direction == :asc
              order = Arel::Nodes::Ascending.new(column, nulls)
            else
              order = Arel::Nodes::Descending.new(column, nulls)
            end

            resource = resource.joins(relation.name)
            resource = resource.order(order)
          end
        end
      end

      resource
    end

  end
end