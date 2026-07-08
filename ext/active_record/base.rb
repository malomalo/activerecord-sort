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

      order_columns = []
      ordering.each do |order|
        order = Array(order)
        order.each do |column_or_relation, options|
          if column_or_relation.to_sym == :random
            resource = resource.random_sort
          elsif self.column_names.include?(column_or_relation.to_s)
            resource = resource.sort_for_column(self.arel_table[column_or_relation.to_s], options)
          elsif reflect_on_association(column_or_relation.to_sym)
            resource = resource.sort_for_relation(column_or_relation.to_sym, options, order_columns)
          else
            raise ActiveRecord::StatementInvalid.new("Unkown column #{column_or_relation}")
          end
        end
      end
      
      if order_columns.present?
        resource = resource.select(resource.klass.arel_table[Arel::Nodes::SqlLiteral.new('*')], *order_columns)
      end

      resource
    end
    
    def random_sort
      self.order(Arel::Nodes::RandomOrdering.new)
    end

    # TODO: probably don't need to cast to sym
    def sort_for_column(column, options)
      direction = (options.is_a?(Hash) || options.class.name == "ActionController::Parameters" ? options.keys.first.to_sym : options.to_s.downcase.to_sym)

      nulls = (options.is_a?(Hash) ? options.values.first.to_sym : nil)
      if direction == :desc
        self.order(Arel::Nodes::Descending.new(column, nulls))
      elsif direction == :asc || direction == :''
        self.order(Arel::Nodes::Ascending.new(column, nulls))
      else
        raise ActiveRecord::StatementInvalid.new("Unkown ordering #{direction}")
      end
    end

    def sort_for_relation(relation, options, order_columns)
      resource = self
      relation = reflect_on_association(relation)

      if relation.macro == :has_many
        options = [options] if !options.is_a?(Array)

        options.each do |order|
          Array(order).each do |column_name, options|
            # Alias the select column (ar_sort_*) so it can't overwrite a
            # same-named attribute on this table when records are loaded.
            column = Arel::Attributes::Relation.new(relation.klass.arel_table[column_name], relation.name)
            order_columns.push(column.as("ar_sort_#{order_columns.size}"))
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
      elsif relation.macro == :has_and_belongs_to_many
        options = [options] if !options.is_a?(Array)
        
        options.each do |order|
          Array(order).each do |column_name, options|
            # LEFT JOIN the collection and order by the MIN of the requested
            # column, grouped by this table's primary key, so rows don't fan /
            # duplicate and records with an empty collection still appear:
            #
            #   SELECT properties.*, MIN(tags.name) AS ar_sort_0
            #   FROM properties
            #   LEFT JOIN properties_tags ON properties_tags.property_id = properties.id
            #   LEFT JOIN tags ON tags.id = properties_tags.tag_id
            #   GROUP BY properties.id
            #   ORDER BY MIN(tags.name) ASC
            #
            # MIN is the sort key for both directions so toggling asc/desc
            # reverses the list instead of re-keying multi-value records, and
            # the ORDER BY uses the aggregate expression rather than its alias
            # so readers that replace the select list (pluck, ids) keep the
            # sort.
            #
            # TODO: When version <= 8.0 dropped move to remove alias_node
            # and move to
            #   column = column.minimum.as("ar_sort_#{order_columns.size}")
            #   order_columns.push(column)
            #   ...
            #   and use column.right where alias_node was used
            #
            # Build the As node explicitly rather than via Function#as: on
            # ActiveRecord <= 8.0, Function#as mutates the receiver and
            # returns the Min node itself (not an Arel::Nodes::As), so its
            # return value can't be relied on across supported versions.
            column = Arel::Attributes::Relation.new(relation.klass.arel_table[column_name], relation.name)
            alias_node = Arel::Nodes::SqlLiteral.new("ar_sort_#{order_columns.size}")
            order_columns.push(Arel::Nodes::As.new(column.minimum, alias_node))
            direction = (options.is_a?(Hash) ? options.keys.first.to_sym : options.to_s.downcase.to_sym)

            nulls = (options.is_a?(Hash) ? options.values.first.to_sym : nil)
            order = if direction == :desc
              Arel::Nodes::Descending.new(alias_node, nulls)
            else
              Arel::Nodes::Ascending.new(alias_node, nulls)
            end

            resource = resource.left_outer_joins(relation.name)
            resource = resource.group(klass.arel_table[klass.primary_key])
            resource = resource.order(order)
          end
        end
      elsif relation.macro == :belongs_to || relation.macro == :has_one
        options = [options] if !options.is_a?(Array)

        options.each do |order|
          order = Array(order)
          order.each do |column, options|
            # Alias the select column (ar_sort_*) so it can't overwrite a
            # same-named attribute on this table when records are loaded.
            column = relation.klass.arel_table[column]
            order_columns.push(column.as("ar_sort_#{order_columns.size}"))
            direction = (options.is_a?(Hash) ? options.keys.first.to_sym : options.to_s.downcase.to_sym)

            nulls = (options.is_a?(Hash) ? options.values.first.to_sym : nil)
            if direction == :desc
              order = Arel::Nodes::Descending.new(column, nulls)
            else
              order = Arel::Nodes::Ascending.new(column, nulls)
            end

            resource = resource.left_outer_joins(relation.name)
            resource = resource.order(order)
          end
        end
      end

      resource
    end

  end
end
