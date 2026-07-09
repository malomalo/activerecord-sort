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
            resource = resource.sort_for_column(self.arel_table[column_or_relation.to_s], options)
          elsif reflect_on_association(column_or_relation.to_sym)
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

    # Normalizes per-column sort options into [direction, nulls]. A blank
    # direction — a bare column, or "" as query params often produce —
    # means :asc.
    # TODO: probably don't need to cast to sym
    def sort_direction_and_nulls(options)
      if options.is_a?(Hash) || options.class.name == "ActionController::Parameters"
        [options.keys.first.to_sym, options.values.first.to_sym]
      elsif options.blank?
        [:asc, nil]
      else
        [options.to_s.downcase.to_sym, nil]
      end
    end

    def sort_for_column(column, options)
      direction, nulls = sort_direction_and_nulls(options)

      if direction == :desc
        self.order(Arel::Nodes::Descending.new(column, nulls))
      elsif direction == :asc
        self.order(Arel::Nodes::Ascending.new(column, nulls))
      else
        raise ActiveRecord::StatementInvalid.new("Unkown ordering #{direction}")
      end
    end

    # The sort key lives only in the ORDER BY — nothing is added to the
    # select list. That keeps the ORDER BY self-contained (so pluck/ids,
    # which replace the select list, keep the sort), leaves the caller's
    # select untouched, and means loaded records carry exactly their own
    # attributes (a selected join column would overwrite a same-named
    # attribute on the base table).
    def sort_for_relation(relation, options)
      resource = self
      relation = reflect_on_association(relation)

      if relation.macro == :has_many || relation.macro == :has_and_belongs_to_many
        options = [options] if !options.is_a?(Array)

        options.each do |order|
          Array(order).each do |column_name, options|
            # LEFT JOIN the collection, group by this table's primary key —
            # so rows don't fan / duplicate and records with an empty
            # collection still appear — and order by an aggregate of the
            # requested column:
            #
            #   SELECT properties.*
            #   FROM properties
            #   LEFT JOIN properties_tags ON properties_tags.property_id = properties.id
            #   LEFT JOIN tags ON tags.id = properties_tags.tag_id
            #   GROUP BY properties.id
            #   ORDER BY MIN(tags.name) ASC
            #
            # Ascending keys each record by its smallest member (MIN),
            # descending by its largest (MAX) — the member you'd expect to
            # see first in that direction. Toggling asc/desc therefore
            # re-keys multi-value records rather than strictly reversing
            # the list.
            column = Arel::Attributes::Relation.new(relation.klass.arel_table[column_name], relation.name)
            direction, nulls = sort_direction_and_nulls(options)

            order = if direction == :desc
              Arel::Nodes::Descending.new(column.maximum, nulls)
            elsif direction == :asc
              Arel::Nodes::Ascending.new(column.minimum, nulls)
            else
              raise ActiveRecord::StatementInvalid.new("Unkown ordering #{direction}")
            end

            resource = resource.left_outer_joins(relation.name)
            resource = resource.order(order)
          end
        end
      elsif relation.macro == :belongs_to || relation.macro == :has_one
        options = [options] if !options.is_a?(Array)

        options.each do |order|
          order = Array(order)
          order.each do |column, options|
            column = relation.klass.arel_table[column]
            direction, nulls = sort_direction_and_nulls(options)

            if direction == :desc
              order = Arel::Nodes::Descending.new(column.maximum, nulls)
            elsif direction == :asc
              order = Arel::Nodes::Ascending.new(column.minimum, nulls)
            else
              raise ActiveRecord::StatementInvalid.new("Unkown ordering #{direction}")
            end

            resource = resource.left_outer_joins(relation.name)
            resource = resource.order(order)
          end
        end
      end

      resource = resource.group(klass.arel_table[klass.primary_key])
      # Tag the relation for the count override below. Chained relations
      # are built with clone, which copies instance variables, so the tag
      # survives further chaining.
      resource.instance_variable_set(:@sorted_by_relation, true)
      resource
    end

  end

  module Sort
    module Calculations
      # sort_for_relation groups by the primary key and LEFT JOINs the
      # relation, so aggregates would see grouped, fanned-out rows: count
      # returns a per-group Hash, and sum/average weigh a record once per
      # collection member. But a relation sort is order-only — records are
      # never added or removed — so every aggregate has a well-defined
      # answer: compute it over the base table restricted to the sorted
      # relation's (distinct) primary keys. User joins and conditions still
      # apply inside the subquery, and a user-added group falls through to
      # the standard grouped behavior.
      def calculate(operation, column_name)
        if @sorted_by_relation && group_values == [klass.arel_table[klass.primary_key]]
          klass.where(klass.primary_key => unscope(:group, :order, :select).select(klass.primary_key))
               .calculate(operation, column_name)
        else
          super
        end
      end
    end
  end
end

ActiveRecord::Relation.prepend(ActiveRecord::Sort::Calculations)
