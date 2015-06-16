module Yito
  module Model
    module Booking
      module Queries

        def self.extended(model)
          model.extend ClassMethods
        end

        module ClassMethods
          
          def incoming_money_summary(year)
            query_strategy.incoming_money_summary(year)
          end

          def reservations_received(year)
            query_strategy.reservations_received(year)
          end

          def reservations_confirmed(year)
            query_strategy.reservations_confirmed(year)
          end

          def occupation(from, to)

            query = <<-QUERY
               SELECT l.item_id as item_id, c.stock as stock, count(*) as busy 
               FROM bookds_bookings_lines as l
               JOIN bookds_bookings as b on b.id = l.booking_id
               JOIN bookds_categories as c on c.code = l.item_id
               WHERE (b.date_from <= '#{from}' and b.date_to >= '#{from}') or 
                   (b.date_from <= '#{to}' and b.date_to >= '#{to}') or 
                   (b.date_from = '#{from}' and b.date_to = '#{to}') or
                   (b.date_from >= '#{from}' and b.date_to <= '#{to}')
               GROUP BY l.item_id, c.stock
            QUERY

            occupation = repository.adapter.select(query)

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