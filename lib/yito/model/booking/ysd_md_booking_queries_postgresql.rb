module Yito
  module Model
    module Booking
      class PostgresqlQueries

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
                  unaccent(customer_surname) ilike unaccent('#{search_text}%')
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
                  unaccent(customer_surname) ilike unaccent('%#{search_text}%')
            group by customer_email, customer_phone, customer_mobile_phone, unaccent(customer_surname), unaccent(customer_name)
          QUERY
          @repository.adapter.select(query).first
        end

        # Get the first booking that matches the customer
        #
        def first_customer_booking(params)
          BookingDataSystem::Booking.by_sql{ |b| [first_customer_booking_query(b,params)] }.first
        end
        
        #
        # Booking text search
        #
        def text_search(search_text, offset_order_query)
          BookingDataSystem::Booking.by_sql{ |b| [text_search_query(b,search_text)] }.all(offset_order_query)
        end

        def count_text_search(search_text)
          query = <<-QUERY
            select count(*) 
            FROM bookds_bookings 
            where id = #{search_text.to_i} or
                  customer_email = '#{search_text}' or 
                  customer_phone = '#{search_text}' or 
                  customer_mobile_phone = '#{search_text}' or
                  unaccent(customer_surname) ilike unaccent('%#{search_text}%')
          QUERY
          @repository.adapter.select(query).first
        end

        def incoming_money_summary(year)

          query = <<-QUERY
             SELECT TO_CHAR(date_from, 'YYYY-MM') as period, 
                 sum(total_cost) as total
             FROM bookds_bookings
             WHERE status IN (2,3,4) and date_part('year', date_from) = #{year.to_i}
             GROUP BY period
             ORDER by period
          QUERY

          summary = @repository.adapter.select(query)

        end

        def reservations_received(year)
       
          query = <<-QUERY
             SELECT TO_CHAR(creation_date, 'YYYY-MM') as period, 
                 count(*) as occurrences
             FROM bookds_bookings 
             WHERE date_part('year', creation_date) = #{year.to_i}
             GROUP BY period
             order by period
          QUERY

          reservations=@repository.adapter.select(query)

        end

        def reservations_confirmed(year)
       
          query = <<-QUERY
             SELECT TO_CHAR(creation_date, 'YYYY-MM') as period, 
                  count(*) as occurrences
             FROM bookds_bookings
             WHERE status IN (2,3,4) and date_part('year', creation_date) = #{year.to_i}
             GROUP BY period 
             order by period
          QUERY

          reservations=@repository.adapter.select(query)

        end

        def count_received_reservations(year)
 
          query = <<-QUERY
            select count(*) 
            FROM bookds_bookings 
            where date_part('year', creation_date) = #{year.to_i}
            QUERY

          @repository.adapter.select(query).first
        end

        def count_pending_confirmation_reservations(year)

          query = <<-QUERY
            select count(*) 
            FROM bookds_bookings 
            where date_part('year', creation_date) = #{year.to_i} and status = 1
            QUERY

          @repository.adapter.select(query).first
        end

        def count_confirmed_reservations(year)

          query = <<-QUERY
            select count(*) 
            FROM bookds_bookings 
            where date_part('year', creation_date) = #{year.to_i} and status = 2
            QUERY

          @repository.adapter.select(query).first
        end        

        def reservations_by_weekday(year)

          query = <<-QUERY
            select count(*), date_part('DOW', creation_date) as day 
            FROM bookds_bookings 
            where date_part('year', creation_date) = #{year.to_i} and status <> 5
            group by day
            order by day
          QUERY

          @repository.adapter.select(query)

        end 

        def reservations_by_category(year)
          
          query = <<-QUERY
            select item_id, count(*) as count  
            FROM bookds_bookings_lines 
            JOIN bookds_bookings on bookds_bookings.id = bookds_bookings_lines.booking_id
            where date_part('year', creation_date) = #{year.to_i} and status <> 5
            group by item_id
            order by item_id
          QUERY

          @repository.adapter.select(query)

        end

        def reservations_by_status(year)

          query = <<-QUERY
            select status, count(*) as count  
            FROM bookds_bookings 
            where date_part('year', creation_date) = #{year.to_i}
            group by status
            order by status
          QUERY

          @repository.adapter.select(query)

        end

        def last_30_days_reservations
 
          query = <<-QUERY
             SELECT (now()::date - creation_date::date) as period, 
             count(*) as occurrences
             FROM bookds_bookings
             WHERE creation_date >= (now() - INTERVAL '30 day')
             GROUP BY period 
             order by period desc
          QUERY

          reservations=@repository.adapter.select(query)

        end

        private

        def text_search_query(b,search_text)
          query = <<-QUERY
            select #{b.*} FROM #{b} 
            where #{b.id} = #{search_text.to_i} or
                  #{b.customer_email} = '#{search_text}' or 
                  #{b.customer_phone} = '#{search_text}' or 
                  #{b.customer_mobile_phone} = '#{search_text}' or
                  unaccent(#{b.customer_surname}) ilike unaccent('#{search_text}%')
          QUERY

        end 

        def first_customer_booking_query(b,params)
          query = <<-QUERY
            select #{b.*} FROM #{b} 
            where #{b.customer_email} = '#{params[:customer_email]}' and 
                  #{b.customer_phone} = '#{params[:customer_phone]}' and
                  unaccent(#{b.customer_surname}) ilike unaccent('#{params[:customer_surname]}') and
                  unaccent(#{b.customer_name}) ilike unaccent('#{params[:customer_name]}')
          QUERY

        end 

      end
    end
  end
end