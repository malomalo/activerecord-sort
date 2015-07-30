module Arel
  module Nodes
    class Ascending < Ordering

      attr_accessor :nulls

      def initialize expr, nulls=nil
        super(expr)
        @expr = expr
        @nulls = nulls
      end

    end
  end
end