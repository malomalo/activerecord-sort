module Arel
  module Visitors
    class PostgreSQL
      private
      
      def visit_Arel_Nodes_Ascending o, collector
        case o.nulls
        when :nulls_first then visit(o.expr, collector) << ' ASC NULLS FIRST'
        when :nulls_last  then visit(o.expr, collector) << ' ASC NULLS LAST'
        else visit(o.expr, collector) << ' ASC'
        end
      end

      def visit_Arel_Nodes_Descending o, collector
        case o.nulls
        when :nulls_first then visit(o.expr, collector) << ' DESC NULLS FIRST'
        when :nulls_last  then visit(o.expr, collector) << ' DESC NULLS LAST'
        else visit(o.expr, collector) << ' DESC'
        end
      end
      
    end
  end
end
