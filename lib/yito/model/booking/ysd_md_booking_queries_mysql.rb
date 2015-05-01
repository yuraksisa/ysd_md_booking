module Yito
  module Model
    module Booking
      class MySQLQueries

        def initialize(repository)
          @repository = repository
        end
 
        def incoming_money_summary(year)

          query = <<-QUERY
             SELECT DATE_FORMAT(date_from, '%Y-%m') as period, 
                 sum(total_cost) as total
             FROM bookds_bookings
             WHERE status IN (2,3,4) and YEAR(date_from) = #{year.to_i}
             GROUP BY period
             ORDER by period
          QUERY

          summary = @repository.adapter.select(query)

        end

        #
        # Get the reservations received grouped by month
        #
        def reservations_received(year)
       
          query = <<-QUERY
             SELECT DATE_FORMAT(creation_date, '%Y-%m') as period, 
                 count(*) as occurrences
             FROM bookds_bookings
             WHERE YEAR(creation_date) = #{year.to_i}
             GROUP BY period
             ORDER by period
          QUERY

          reservations=@repository.adapter.select(query)

        end

        #
        # Get the reservations confirmed grouped by month
        #
        def reservations_confirmed(year)
       
          query = <<-QUERY
             SELECT DATE_FORMAT(creation_date, '%Y-%m') as period, 
                 count(*) as occurrences
             FROM bookds_bookings
             WHERE status IN (2,3,4) and YEAR(creation_date) = #{year.to_i}
             GROUP BY period 
             ORDER by period
         QUERY

         reservations=@repository.adapter.select(query)

       end

      end
    end
  end
end