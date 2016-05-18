module Yito
  module Model
    module Booking
      class SQLiteQueries

        def initialize(repository)
          @repository = repository
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

        def incoming_money_summary(year)

          query = <<-QUERY
             SELECT TO_CHAR(date_from, 'YYYY-MM') as period, 
                 sum(total_cost) as total
             FROM bookds_bookings
             WHERE status IN (2,3,4) and strftime('%Y', date_from) = #{year.to_i}
             GROUP BY period
             ORDER by period
          QUERY

          summary = @repository.adapter.select(query)

        end

        def reservations_received(year)
       
          query = <<-QUERY
             SELECT TO_CHAR(creation_date, 'YYYY-MM') as period, 
                 count(*) as occurrences
             FROM bookds_bookings and strftime('%Y', creation_date) = #{year.to_i}
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
             WHERE status NOT IN (1,5) and strftime('%Y', creation_date) = #{year.to_i}
             GROUP BY period 
             order by period
          QUERY

          reservations=@repository.adapter.select(query)

        end

        def count_received_reservations(year)
 
          query = <<-QUERY
            select count(*) 
            FROM bookds_bookings 
            where strftime('%Y', creation_date) = #{year.to_i}= #{year.to_i}
            QUERY

          @repository.adapter.select(query).first
        end

        def count_pending_confirmation_reservations(year)

          query = <<-QUERY
            select count(*) 
            FROM bookds_bookings 
            where strftime('%Y', creation_date) = #{year.to_i} = #{year.to_i} and status = 1 and
                  date_from > ?
            QUERY

          @repository.adapter.select(query, [Date.today.to_date]).first
        end

        def count_confirmed_reservations(year)

          query = <<-QUERY
            select count(*) 
            FROM bookds_bookings 
            where strftime('%Y', creation_date) = #{year.to_i} = #{year.to_i} and status IN (2,3,4)
            QUERY

          @repository.adapter.select(query).first
        end         

        #
        # Get the products total billing
        #
        def products_billing_total(year)
          query = <<-QUERY
            select sum(b.item_cost) as total_item_cost
            from bookds_bookings b
            where strftime('%Y', b.date_from) = ? and 
                  b.status NOT IN (1,5)         
          QUERY

          @repository.adapter.select(query, [year])
        end
          
        #
        # Get the extras total billing
        #
        def extras_billing_total(year)
          query = <<-QUERY
            select sum(b.time_from_cost + b.time_to_cost + b.pickup_place_cost + b.return_place_cost) as total_extra_cost
            from bookds_bookings b
            where strftime('%Y', b.date_from) = ? and 
                  b.status NOT IN (1,5) and 
                  (b.time_from_cost > 0 or b.time_to_cost > 0 or b.pickup_place_cost > 0 or
                   b.return_place_cost > 0)
            union
            select sum(e.extra_cost) as total_extra_cost
            from bookds_bookings_extras e
            join bookds_bookings b on e.booking_id = b.id
            where strftime('%Y', b.date_from) = #{year.to_i} and 
                  b.status NOT IN (1,5) and 
                  e.extra_cost > 0 and
                  e.extra_id in (select code from bookds_extras)     
          QUERY

          @repository.adapter.select(query, [year])
        end        

        #
        # Get the stock total cost
        #
        def stock_cost_total
          query = <<-QUERY
            select sum(i.cost) as total
            from bookds_items i
            where i.active = ?         
          QUERY
          repository.adapter.select(query, [1])
        end

        def products_billing_summary_by_stock(year)
          query = <<-QUERY
            select r.booking_item_reference as reference, 
                   TO_CHAR(creation_date, 'MM') as period,
                   sum(b.item_cost) as total_item_cost
            from bookds_bookings_lines_resources r 
            join bookds_bookings_lines l on r.booking_line_id = l.id
            join bookds_bookings b on l.booking_id = b.id 
            where strftime('%Y', b.date_from) = ? and 
                  b.status NOT IN (1,5)
            group by reference, period
            order by reference, period          
          QUERY

          @repository.adapter.select(query, [year])
        end

        def extras_billing_summary_by_extra(year)
          query = <<-QUERY
            select e.extra_id as extra, 
                   TO_CHAR(creation_date, 'MM') as period,
                   sum(e.extra_cost) as total_extra_cost
            from bookds_bookings_extras e
            join bookds_bookings b on e.booking_id = b.id
            where strftime('%Y', b.date_from) = ? and 
                  b.status NOT IN (1,5)
            group by extra, period
            union
            select 'entrega_fuera_horas' as extra,
                   TO_CHAR(b.date_from, 'MM') as period,
                   sum(b.time_from_cost) as total_extra_cost
            from bookds_bookings b
            where strftime('%Y', b.date_from) = #{year.to_i} and 
                  b.status NOT IN (1,5) and 
                  b.time_from_cost > 0
            group by period
            union
            select 'recogida_fuera_horas' as extra,
                   TO_CHAR(b.date_from, 'MM') as period,
                   sum(b.time_to_cost) as total_extra_cost
            from bookds_bookings b
            where strftime('%Y', b.date_from) = #{year.to_i} and 
                  b.status NOT IN (1,5) and 
                  b.time_to_cost > 0
            group by period
            union
            select 'lugar_entrega' as extra,
                   TO_CHAR(b.date_from, 'MM') as period,
                   sum(b.pickup_place_cost) as total_extra_cost
            from bookds_bookings b
            where strftime('%Y', b.date_from) = #{year.to_i} and 
                  b.status NOT IN (1,5) and 
                  b.pickup_place_cost > 0
            group by period
            union
            select 'lugar_recogida' as extra,
                   TO_CHAR(b.date_from, 'MM') as period,
                   sum(b.return_place_cost) as total_extra_cost
            from bookds_bookings b
            where strftime('%Y', b.date_from) = #{year.to_i} and 
                  b.status NOT IN (1,5) and 
                  b.return_place_cost > 0
            group by period
          QUERY

          @repository.adapter.select(query, year)
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