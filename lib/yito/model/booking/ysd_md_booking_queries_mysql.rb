module Yito
  module Model
    module Booking
      class MySQLQueries

        def initialize(repository)
          @repository = repository
        end
 
        def incoming_money_summary

          query = <<-QUERY
             SELECT DATE_FORMAT(date_from, '%Y-%M') as period, 
                 sum(total_cost) as total
             FROM bookds_bookings
             WHERE status IN (2,3,4)
             GROUP BY period
             ORDER by period
          QUERY

          summary = @repository.adapter.select(query)

        end

        #
        # Get the reservations received grouped by month
        #
        def reservations_received
       
          query = <<-QUERY
             SELECT DATE_FORMAT(creation_date, '%Y-%M') as period, 
                 count(*) as occurrences
             FROM bookds_bookings
             GROUP BY period
             ORDER by period
          QUERY

          reservations=@repository.adapter.select(query)

        end

        #
        # Get the reservations confirmed grouped by month
        #
        def reservations_confirmed
       
          query = <<-QUERY
             SELECT DATE_FORMAT(creation_date, '%Y-%M') as period, 
                 count(*) as occurrences
             FROM bookds_bookings
             WHERE status IN (2,3,4)
             GROUP BY period 
             ORDER by period
         QUERY

         reservations=@repository.adapter.select(query)

       end

      end
    end
  end
end