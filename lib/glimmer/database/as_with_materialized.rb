# frozen_string_literal: true

module Gitlab
  module Database
    # This class is a special Arel node which allows optionally define the `MATERIALIZED` keyword for CTE and Recursive CTE queries.
    class AsWithMaterialized < Arel::Nodes::Binary
      extend Gitlab::Utils::StrongMemoize

      MATERIALIZED = Arel.sql(' MATERIALIZED')
      EMPTY_STRING = Arel.sql('')
      attr_reader :expr

      def initialize(left, right, materialized: true)
        @expr = if materialized && self.class.materialized_supported?
                  MATERIALIZED
                else
                  EMPTY_STRING
                end

        super(left, right)
      end

      # Note: to be deleted after the minimum PG version is set to 12.0
      def self.materialized_supported?
        strong_memoize(:materialized_supported) do
          Gitlab::Database.version.match?(/^1[2-9]\./) # version 12.x and above
        end
      end

      # Note: to be deleted after the minimum PG version is set to 12.0
      def self.materialized_if_supported
        materialized_supported? ? 'MATERIALIZED' : ''
      end
    end
  end
end
