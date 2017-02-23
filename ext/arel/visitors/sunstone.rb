module Arel
  module Visitors
    class Sunstone
      def visit_Arel_Nodes_RandomOrdering o, collector
        :random
      end
    end
  end
end