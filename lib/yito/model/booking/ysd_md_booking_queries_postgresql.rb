module Yito
  module Model
    module Booking
      class PostgresqlQueries

        def initialize(repository)
          @repository = repository
        end

        def incoming_money_summary

          query = <<-QUERY
             SELECT TO_CHAR(date_from, 'YYYY-MM') as period, 
                 sum(total_cost) as total
             FROM bookds_bookings
             WHERE status IN (2,3,4)
             GROUP BY period
             ORDER by period
          QUERY

          summary = @repository.adapter.select(query)

        end

        def reservations_received
       
          query = <<-QUERY
             SELECT TO_CHAR(creation_date, 'YYYY-MM') as period, 
                 count(*) as occurrences
             FROM bookds_bookings
             GROUP BY period
             order by period
          QUERY

          reservations=@repository.adapter.select(query)

        end

        def reservations_confirmed
       
          query = <<-QUERY
             SELECT TO_CHAR(creation_date, 'YYYY-MM') as period, 
                  count(*) as occurrences
             FROM bookds_bookings
             WHERE status IN (2,3,4)
             GROUP BY period 
             order by period
          QUERY

          reservations=@repository.adapter.select(query)

        end

      end
    end
  end
end