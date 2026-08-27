require 'active_record'
require 'active_record/relation'

module ActiveRecord
  # Prepended onto ActiveRecord::QueryMethods (see lib/active_record/sort.rb).
  # Living in a separate module keeps these methods out of
  # QueryMethods.public_instance_methods(false) — which Rails' own
  # delegation tests assert against — while relations still respond to them.
  module Sort

    # Raised when a sort references an unrecognized column or association,
    # or an unknown direction. Subclasses StatementInvalid so existing
    # `rescue ActiveRecord::StatementInvalid` handlers — the safety
    # contract that makes it OK to pass request params straight through —
    # keep working, while callers can rescue this narrower class to tell a
    # bad sort parameter apart from a genuine database error.
    class InvalidSort < ActiveRecord::StatementInvalid
    end

    # ordering:
    # :id
    # :name, :id
    # :id => :desc
    # :id => {:desc => :nulls_last}
    # :listings => :id
    # :listings => {:id => {:asc => :nulls_first}}
    # :random
    def sort(*ordering, &block)
      # With no arguments, fall back to Ruby's Enumerable#sort so code (and
      # Rails' own test suite) that calls `relation.sort` expecting Ruby
      # semantics keeps working. The ordering DSL only applies when given
      # arguments; `sort(nil)`/`sort([])` still return the relation for
      # chaining.
      return super(&block) if ordering.empty?

      resource = all
      ordering.compact!
      ordering.flatten!
      return resource if ordering.size == 0

      ordering.each do |order|
        order = Array(order)
        order.each do |column_or_relation, options|
          if column_or_relation.to_sym == :random
            resource = resource.order(Arel::Nodes::RandomOrdering.new)
          elsif self.column_names.include?(column_or_relation.to_s)
            resource = resource.sort_for_column(self.arel_table[column_or_relation.to_s], options)
          elsif reflect_on_association(column_or_relation.to_sym)
            resource = resource.sort_for_relation(column_or_relation.to_sym, options)
          else
            raise InvalidSort.new("Unknown column #{column_or_relation}")
          end
        end
      end

      resource
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
        raise InvalidSort.new("Unknown ordering #{direction}")
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
      options = [options] if !options.is_a?(Array)

      # LEFT JOIN the association, group by this table's primary key — so
      # rows don't fan / duplicate and records with an empty collection
      # still appear — and order by an aggregate of the requested column:
      #
      #   SELECT properties.*
      #   FROM properties
      #   LEFT JOIN properties_tags ON properties_tags.property_id = properties.id
      #   LEFT JOIN tags ON tags.id = properties_tags.tag_id
      #   GROUP BY properties.id
      #   ORDER BY MIN(tags.name) ASC
      #
      # Ascending keys each record by its smallest member (MIN), descending
      # by its largest (MAX) — the member you'd expect to see first in that
      # direction. Toggling asc/desc therefore re-keys multi-value records
      # rather than strictly reversing the list.
      options.each do |order|
        Array(order).each do |column_name, column_options|
          if !relation.klass.column_names.include?(column_name.to_s)
            raise InvalidSort.new("Unknown column #{column_name}")
          end

          # A collection (has_many / has_and_belongs_to_many) wraps the
          # attribute in an Arel::Attributes::Relation so the aggregate
          # references the joined table correctly; a singular association
          # (belongs_to / has_one) uses the plain attribute.
          column = if relation.collection?
            Arel::Attributes::Relation.new(relation.klass.arel_table[column_name], relation.name)
          else
            relation.klass.arel_table[column_name]
          end

          direction, nulls = sort_direction_and_nulls(column_options)

          order = if direction == :desc
            Arel::Nodes::Descending.new(column.maximum, nulls)
          elsif direction == :asc
            Arel::Nodes::Ascending.new(column.minimum, nulls)
          else
            raise InvalidSort.new("Unknown ordering #{direction}")
          end

          resource = resource.left_outer_joins(relation.name)
          resource = resource.order(order)
        end
      end

      # Group by the primary key so the aggregate collapses the joined,
      # fanned-out rows to one per record. Every relation sort adds this,
      # so only add it once: ActiveRecord < 8.1's group! appends rather
      # than unioning, which would leave a duplicate [pk, pk] that trips
      # the count override's group_values check below.
      # TODO: once Rails <= 8.0 is no longer supported, group! unions on
      # its own — drop the include? guard and just group(primary_key).
      primary_key = klass.arel_table[klass.primary_key]
      resource = resource.group(primary_key) unless resource.group_values.include?(primary_key)
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
