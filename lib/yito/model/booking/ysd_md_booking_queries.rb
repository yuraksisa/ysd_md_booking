module Yito
  module Model
    module Booking
      module Queries

        def self.extended(model)
          model.extend ClassMethods
        end

        module ClassMethods
          
          def incoming_money_summary
            query_strategy.incoming_money_summary
          end

          def reservations_received
            query_strategy.reservations_received
          end

          def reservations_confirmed
            query_strategy.reservations_confirmed
          end

          private
    
          def query_strategy
      
            @query_strategy ||= 
               if DataMapper::Adapters.const_defined?(:PostgresAdapter) and repository.adapter.is_a?DataMapper::Adapters::PostgresAdapter
                 PostgresqlQueries.new(repository)
               else
                 if DataMapper::Adapters.const_defined?(:MysqlAdapter) and repository.adapter.is_a?DataMapper::Adapters::MysqlAdapter
                   MySQLQueries.new(repository)
                 else
                   if DataMapper::Adapters.const_defined?(:SqliteAdapter) and repository.adapter.is_a?DataMapper::Adapters::SqliteAdapter
                     SQLiteQueries.new(repository)
                   end
                 end
               end
      
          end

        end

      end
    end
  end
end