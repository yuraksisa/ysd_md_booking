module Yito
  module Model
    module Booking
      class MySQLQueries

        def initialize(repository)
          @repository = repository
        end
 
        def customer_search(search_text, offset_order_query)
          query = <<-QUERY
            select trim(upper(customer_surname)) as customer_surname, trim(upper(customer_name)) as customer_name, 
                   lower(customer_email) as customer_email, customer_phone, count(*) as num_of_reservations
            FROM bookds_bookings 
            where customer_email = '#{search_text}' or 
                  customer_phone = '#{search_text}' or 
                  customer_mobile_phone = '#{search_text}' or
                  customer_surname like '#{search_text}%'
            group by trim(upper(customer_surname)), trim(upper(customer_name)), lower(customer_email), customer_phone
            order by customer_surname, customer_name
          QUERY
          @repository.adapter.select(query)
        end

        def count_customer_search(search_text)
          query = <<-QUERY
            select count(*) 
            FROM bookds_bookings 
            where customer_email = '#{search_text}' or 
                  customer_phone = '#{search_text}' or 
                  customer_mobile_phone = '#{search_text}' or
                  customer_surname like '%#{search_text}%'
            group by trim(upper(customer_surname)), trim(upper(customer_name)), lower(customer_email), customer_phone
            QUERY
          @repository.adapter.select(query).first
        end

        # Get the first booking that matches the customer
        #
        def first_customer_booking(params)
          BookingDataSystem::Booking.by_sql{ |b| [first_customer_booking_query(b,params)] }.first
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

        def count_received_reservations(year)
 
          query = <<-QUERY
            select count(*) 
            FROM bookds_bookings 
            where YEAR(creation_date) = #{year.to_i}
            QUERY

          @repository.adapter.select(query).first
        end

        def count_pending_confirmation_reservations(year)

          query = <<-QUERY
            select count(*) 
            FROM bookds_bookings 
            where YEAR(creation_date) = #{year.to_i} and status = 1
            QUERY

          @repository.adapter.select(query).first
        end

        def count_confirmed_reservations(year)

          query = <<-QUERY
            select count(*) 
            FROM bookds_bookings 
            where YEAR(creation_date) = #{year.to_i} and status = 2
            QUERY

          @repository.adapter.select(query).first
        end         

        def reservations_by_weekday(year)

          query = <<-QUERY
            select count(*) as count, DAYOFWEEK(creation_date) as day 
            FROM bookds_bookings 
            where YEAR(creation_date) = #{year.to_i} and status <> 5
            group by day
            order by day
          QUERY

          @repository.adapter.select(query)

        end 

        def reservations_by_category(year)
          
          query = <<-QUERY
            select bookds_bookings_lines.item_id, count(*) as count  
            FROM bookds_bookings_lines 
            JOIN bookds_bookings on bookds_bookings.id = bookds_bookings_lines.booking_id
            where YEAR(creation_date) = #{year.to_i} and status NOT IN (1,5)
            group by bookds_bookings_lines.item_id
            order by bookds_bookings_lines.item_id
          QUERY

          @repository.adapter.select(query)

        end        

        def reservations_by_status(year)

          query = <<-QUERY
            select CAST(status as SIGNED) status, count(*) as count  
            FROM bookds_bookings 
            where YEAR(creation_date) = #{year.to_i}
            group by status
            order by status    
          QUERY

          @repository.adapter.select(query)

        end

        def last_30_days_reservations
 
          query = <<-QUERY
            SELECT DATEDIFF(CURRENT_DATE(), DATE_FORMAT(creation_date,'%Y-%m-%d')) as period, 
                   count(*) as occurrences
            FROM bookds_bookings
            WHERE DATEDIFF(CURRENT_DATE(), DATE_FORMAT(creation_date,'%Y-%m-%d')) <= 30
            GROUP BY period 
          QUERY

          reservations=@repository.adapter.select(query)

        end

        private

        def first_customer_booking_query(b,params)
          query = <<-QUERY
            select #{b.*} FROM #{b} 
            where #{b.customer_email} = '#{params[:customer_email]}' and 
                  #{b.customer_phone} = '#{params[:customer_phone]}' and
                  #{b.customer_surname} like '#{params[:customer_surname]}' and
                  #{b.customer_name} like '#{params[:customer_name]}'
          QUERY

        end        

      end
    end
  end
end