module Yito
  module Model
    module Booking
      class MySQLQueries

        def initialize(repository)
          @repository = repository
        end
 
        def date_diff(from_field, to_field, alias_name)
          "DATEDIFF(#{to_field}, #{from_field}) as #{alias_name}"
        end     

        def customer_search(search_text, offset_order_query)
          query = <<-QUERY
            select trim(upper(customer_surname)) as customer_surname, trim(upper(customer_name)) as customer_name, 
                   lower(customer_email) as customer_email, customer_phone, count(*) as num_of_reservations
            FROM bookds_bookings 
            where lower(customer_email) = '#{search_text}' or 
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

        # Incoming money summary
        #
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
             WHERE status NOT IN (1,5) and YEAR(creation_date) = #{year.to_i}
             GROUP BY period 
             ORDER by period
         QUERY

         reservations=@repository.adapter.select(query)

        end

        # Received reservations
        #
        def count_received_reservations(year)
 
          query = <<-QUERY
            select count(*) 
            FROM bookds_bookings 
            where YEAR(creation_date) = #{year.to_i}
            QUERY

          @repository.adapter.select(query).first
        end

        # Pending reservations
        #
        def count_pending_confirmation_reservations(year)

          query = <<-QUERY
            select count(*) 
            FROM bookds_bookings 
            where YEAR(creation_date) = #{year.to_i} and status = 1 and date_from > ?
            QUERY

          @repository.adapter.select(query, [Date.today.to_date]).first
        end

        # Confirmed reservations
        #
        def count_confirmed_reservations(year)

          query = <<-QUERY
            select count(*) 
            FROM bookds_bookings 
            where YEAR(creation_date) = #{year.to_i} and status IN (2,3,4)
            QUERY

          @repository.adapter.select(query).first
        end         

        #
        # Total products billing
        #
        def products_billing_total(year)
          query = <<-QUERY
            select sum(b.item_cost) as total_item_cost
            from bookds_bookings b
            where YEAR(b.date_from) = ? and 
                  b.status NOT IN (1,5)         
          QUERY

          @repository.adapter.select(query, [year])
        end
          
        #
        # Total extras billing
        #
        def extras_billing_total(year)
          query = <<-QUERY
            select sum(b.time_from_cost + b.time_to_cost + b.pickup_place_cost + b.return_place_cost) as total_extra_cost
            from bookds_bookings b
            where YEAR(b.date_from) = ? and 
                  b.status NOT IN (1,5) and 
                  (b.time_from_cost > 0 or b.time_to_cost > 0 or b.pickup_place_cost > 0 or
                   b.return_place_cost > 0)
            union
            select sum(e.extra_cost) as total_extra_cost
            from bookds_bookings_extras e
            join bookds_bookings b on e.booking_id = b.id
            where YEAR(b.date_from) = #{year.to_i} and 
                  b.status NOT IN (1,5) and 
                  e.extra_cost > 0 and
                  e.extra_id in (select code from bookds_extras)                  
          QUERY

          @repository.adapter.select(query, [year])
        end

        #
        # Total charged
        #
        def total_charged(year)
          query = <<-QUERY
            select c.payment_method_id as payment_method, sum(c.amount) as total
            from bookds_bookings b
            join bookds_booking_charges bc on bc.booking_id = b.id
            join payment_charges c on c.id = bc.charge_id
            where b.status NOT IN (1,5) and c.status IN (4) and
                  YEAR(c.date) = ? 
            group by c.payment_method_id
            order by total desc
          QUERY
          @repository.adapter.select(query, [year])
        end

        #
        # Prevision of charges
        #
        def forecast_charged(date_from, date_to)
          query = <<-QUERY
            select sum(b.total_pending) as total, DATE_FORMAT(b.date_from, '%Y-%m') as period 
            from bookds_bookings b
            WHERE b.date_from >= '#{date_from}' and 
                  b.date_from < '#{date_to}' and
                  b.status NOT IN (1,5)
            group by period
          QUERY
          @repository.adapter.select(query)
        end

        #
        # Stock total cost
        #
        def stock_cost_total
          query = <<-QUERY
            select sum(i.cost) as total
            from bookds_items i
            where i.active = ?         
          QUERY
          repository.adapter.select(query, [1])
        end        

        #
        # Billing summary by stock (for the reservations)
        #
        def products_billing_summary_by_stock(year)
          query = <<-QUERY
            select r.booking_item_reference as reference, 
                   DATE_FORMAT(b.date_from, '%m') as period,
                   sum(b.item_cost) as total_item_cost
            from bookds_bookings_lines_resources r 
            join bookds_bookings_lines l on r.booking_line_id = l.id
            join bookds_bookings b on l.booking_id = b.id 
            where YEAR(b.date_from) = ? and 
                  b.status NOT IN (1,5)
            group by reference, period
            order by reference, period          
          QUERY

          @repository.adapter.select(query, [year])
        end

        #
        # Extras summary (for the reservations)
        #
        def extras_billing_summary_by_extra(year)
          query = <<-QUERY
            select e.extra_id as extra, 
                   DATE_FORMAT(b.date_from, '%m') as period,
                   sum(e.extra_cost) as total_extra_cost
            from bookds_bookings_extras e
            join bookds_bookings b on e.booking_id = b.id
            where YEAR(b.date_from) = ? and 
                  b.status NOT IN (1,5) 
            group by extra, period
            union
            select 'entrega_fuera_horas' as extra,
                   DATE_FORMAT(b.date_from, '%m') as period,
                   sum(b.time_from_cost) as total_extra_cost
            from bookds_bookings b
            where YEAR(b.date_from) = #{year.to_i} and 
                  b.status NOT IN (1,5) and 
                  b.time_from_cost > 0
            group by period
            union
            select 'recogida_fuera_horas' as extra,
                   DATE_FORMAT(b.date_from, '%m') as period,
                   sum(b.time_to_cost) as total_extra_cost
            from bookds_bookings b
            where YEAR(b.date_from) = #{year.to_i} and 
                  b.status NOT IN (1,5) and 
                  b.time_to_cost > 0
            group by period
            union
            select 'lugar_entrega' as extra,
                   DATE_FORMAT(b.date_from, '%m') as period,
                   sum(b.pickup_place_cost) as total_extra_cost
            from bookds_bookings b
            where YEAR(b.date_from) = #{year.to_i} and 
                  b.status NOT IN (1,5) and 
                  b.pickup_place_cost > 0
            group by period
            union
            select 'lugar_recogida' as extra,
                   DATE_FORMAT(b.date_from, '%m') as period,
                   sum(b.return_place_cost) as total_extra_cost
            from bookds_bookings b
            where YEAR(b.date_from) = #{year.to_i} and 
                  b.status NOT IN (1,5) and 
                  b.return_place_cost > 0
            group by period
          QUERY

          @repository.adapter.select(query, year)
        end        

        # Reservations by weekday
        #
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

        # Reservations by category
        #
        def reservations_by_category(year)
          
          query = <<-QUERY
            select bookds_bookings_lines.item_id, count(*) as count  
            FROM bookds_bookings_lines 
            JOIN bookds_bookings on bookds_bookings.id = bookds_bookings_lines.booking_id
            where YEAR(creation_date) = #{year.to_i} and status NOT IN (1,5)
            group by bookds_bookings_lines.item_id
            order by count desc
          QUERY

          @repository.adapter.select(query)

        end        

        # Reservations by status
        #
        def reservations_by_status(year)

          query = <<-QUERY
            select CAST(status as SIGNED) status, count(*) as count  
            FROM bookds_bookings 
            where YEAR(creation_date) = #{year.to_i}
            group by status
            order by count desc    
          QUERY

          @repository.adapter.select(query)

        end

        # Last 30 days reservations
        #
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

        # Get the products (or categories) that where booked in a year
        #
        def historic_products(year)

          query = <<-QUERY
            select distinct(bookds_bookings_lines.item_id) 
            FROM bookds_bookings_lines 
            JOIN bookds_bookings on bookds_bookings.id = bookds_bookings_lines.booking_id
            where YEAR(date_from) = #{year.to_i} and status NOT IN (1,5) and bookds_bookings_lines.item_id is not NULL
            order by bookds_bookings_lines.item_id
          QUERY

          @repository.adapter.select(query)

        end

        # Get the stock that where used in the reservations of a year
        def historic_stock(year)

          query = <<-QUERY
            select distinct(bookds_bookings_lines_resources.booking_item_reference) as item_reference,
                   bookds_bookings_lines.item_id as item_id,
                   bookds_bookings_lines_resources.booking_item_category as item_category   
            FROM bookds_bookings_lines_resources
            JOIN bookds_bookings_lines on bookds_bookings_lines_resources.booking_line_id = bookds_bookings_lines.id
            JOIN bookds_bookings on bookds_bookings.id = bookds_bookings_lines.booking_id
            where YEAR(date_from) = #{year.to_i} and status NOT IN (1,5) and booking_item_reference is not NULL
            order by bookds_bookings_lines_resources.booking_item_reference
          QUERY

          @repository.adapter.select(query)

        end

        # Get the extras that where used in the reservations of a year
        def historic_extra(year)

          query = <<-QUERY
            select distinct(bookds_bookings_lines_resources.booking_item_reference) as item_reference,
                   bookds_bookings_lines.item_id as item_id,
                   bookds_bookings_lines_resources.booking_item_category as item_category   
            FROM bookds_bookings_lines_resources
            JOIN bookds_bookings_lines on bookds_bookings_lines_resources.booking_line_id = bookds_bookings_lines.id
            JOIN bookds_bookings on bookds_bookings.id = bookds_bookings_lines.booking_id
            where YEAR(date_from) = #{year.to_i} and status NOT IN (1,5) and booking_item_reference is not NULL
            order by bookds_bookings_lines_resources.booking_item_reference
          QUERY

          @repository.adapter.select(query)

        end

        private

        def first_customer_booking_query(b,params)
          query = <<-QUERY
            select #{b.*} FROM #{b} 
            where TRIM(LOWER(#{b.customer_email})) = '#{params[:customer_email]}' and 
                  TRIM(#{b.customer_phone}) = '#{params[:customer_phone]}' and
                  TRIM(#{b.customer_surname}) like '#{params[:customer_surname]}' and
                  TRIM(#{b.customer_name}) like '#{params[:customer_name]}'
          QUERY

        end        

      end
    end
  end
end