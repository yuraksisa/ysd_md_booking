module Yito
  module Model
    module Booking
      class PostgresqlQueries

        def initialize(repository)
          @repository = repository
        end

        def date_diff(from_field, to_field, alias_name)
          "DATE_PART('day', #{to_field} - #{from_field}) as #{alias_name}"
        end

        def customer_search(search_text, offset_order_query)
          query = <<-QUERY
            select trim(upper(customer_surname)) as customer_surname, trim(upper(customer_name)) as customer_name, 
                   lower(customer_email) as customer_email, customer_phone, count(*) as num_of_reservations
            FROM bookds_bookings 
            where lower(customer_email) = '#{search_text}' or 
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
          BookingDataSystem::Booking.by_sql{ |b| [first_customer_booking_query(b,params)] }.all(order: [:creation_date.desc], offset:0, limit: 1).first
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
            where date_part('year', creation_date) = #{year.to_i} and status = 1 and 
                  date_from > ?
            QUERY

          @repository.adapter.select(query, [Date.today.to_date]).first
        end

        def count_confirmed_reservations(year)

          query = <<-QUERY
            select count(*) 
            FROM bookds_bookings 
            where date_part('year', creation_date) = #{year.to_i} and status IN (2,3,4)
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
            where date_part('year', date_from) = ? and 
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
            where date_part('year', date_from) = ? and 
                  b.status NOT IN (1,5) and 
                  (b.time_from_cost > 0 or b.time_to_cost > 0 or b.pickup_place_cost > 0 or
                   b.return_place_cost > 0)
            union
            select sum(e.extra_cost) as total_extra_cost
            from bookds_bookings_extras e
            join bookds_bookings b on e.booking_id = b.id
            where date_part('year', date_from) = #{year.to_i} and 
                  b.status NOT IN (1,5) and 
                  e.extra_cost > 0 and
                  e.extra_id in (select code from bookds_extras)     
          QUERY

          @repository.adapter.select(query, [year])
        end

        #
        # Get the total charged amount for a year
        #
        def total_charged(year)
          query = <<-QUERY
            select c.payment_method_id as payment_method, sum(c.amount) as total
            from bookds_bookings b
            join bookds_booking_charges bc on bc.booking_id = b.id
            join payment_charges c on c.id = bc.charge_id
            where b.status NOT IN (1,5) and c.status IN (4) and
                  date_part('year', c.date) = ? 
            group by c.payment_method_id
            order by total desc
          QUERY
          @repository.adapter.select(query, [year])
        end

        #
        # Get the forecast charged for a period
        #
        def forecast_charged(date_from, date_to)
          query = <<-QUERY 
            select sum(b.total_pending) as total, TO_CHAR(b.date_from, 'YYYY-MM') as period 
            from bookds_bookings b
            WHERE b.date_from >= '#{date_from}' and 
                  b.date_from < '#{date_to}' and
                  b.status NOT IN (1,5)
            group by period
          QUERY
          @repository.adapter.select(query)
        end

        #
        # Get the stock total cost
        #
        def stock_cost_total
          query = <<-QUERY
            select sum(i.cost) as total
            from bookds_items i
            where i.active = 'true'         
          QUERY
          repository.adapter.select(query)
        end

        def products_billing_summary_by_stock(year)
          query = <<-QUERY
            select r.booking_item_reference as reference, 
                   TO_CHAR(b.date_from, 'MM') as period,
                   sum(b.item_cost) as total_item_cost
            from bookds_bookings_lines_resources r 
            join bookds_bookings_lines l on r.booking_line_id = l.id
            join bookds_bookings b on l.booking_id = b.id 
            where date_part('year', date_from) = ? and 
                  b.status NOT IN (1,5)
            group by reference, period
            order by reference, period          
          QUERY

          @repository.adapter.select(query, [year])
        end

        def extras_billing_summary_by_extra(year)
          query = <<-QUERY
            select e.extra_id as extra, 
                   TO_CHAR(b.date_from, 'MM') as period,
                   sum(e.extra_cost) as total_extra_cost
            from bookds_bookings_extras e
            join bookds_bookings b on e.booking_id = b.id
            where date_part('year', date_from) = #{year.to_i} and 
                  b.status NOT IN (1,5)
            group by extra, period
            union
            select 'entrega_fuera_horas' as extra,
                   TO_CHAR(b.date_from, 'MM') as period,
                   sum(b.time_from_cost) as total_extra_cost
            from bookds_bookings b
            where date_part('year', date_from) = #{year.to_i} and 
                  b.status NOT IN (1,5) and 
                  b.time_from_cost > 0
            group by period
            union
            select 'recogida_fuera_horas' as extra,
                   TO_CHAR(b.date_from, 'MM') as period,
                   sum(b.time_to_cost) as total_extra_cost
            from bookds_bookings b
            where date_part('year', date_from) = #{year.to_i} and 
                  b.status NOT IN (1,5) and 
                  b.time_to_cost > 0
            group by period
            union
            select 'lugar_entrega' as extra,
                   TO_CHAR(b.date_from, 'MM') as period,
                   sum(b.pickup_place_cost) as total_extra_cost
            from bookds_bookings b
            where date_part('year', date_from) = #{year.to_i} and 
                  b.status NOT IN (1,5) and 
                  b.pickup_place_cost > 0
            group by period
            union
            select 'lugar_recogida' as extra,
                   TO_CHAR(b.date_from, 'MM') as period,
                   sum(b.return_place_cost) as total_extra_cost
            from bookds_bookings b
            where date_part('year', date_from) = #{year.to_i} and 
                  b.status NOT IN (1,5) and 
                  b.return_place_cost > 0
            group by period            
          QUERY

          @repository.adapter.select(query)
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
            select bookds_bookings_lines.item_id, count(*) as count  
            FROM bookds_bookings_lines 
            JOIN bookds_bookings on bookds_bookings.id = bookds_bookings_lines.booking_id
            where date_part('year', creation_date) = #{year.to_i} and status NOT IN (1,5)
            group by bookds_bookings_lines.item_id
            order by count desc
          QUERY

          @repository.adapter.select(query)

        end

        def reservations_by_status(year)

          query = <<-QUERY
            select status, count(*) as count  
            FROM bookds_bookings 
            where date_part('year', creation_date) = #{year.to_i}
            group by status
            order by count desc
          QUERY

          @repository.adapter.select(query)

        end

        # Last 30 days reservations
        #
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

        # Get the products (or categories) that where booked in a year
        #
        def historic_products(year)

          query = <<-QUERY
            select distinct(bookds_bookings_lines.item_id) 
            FROM bookds_bookings_lines 
            JOIN bookds_bookings on bookds_bookings.id = bookds_bookings_lines.booking_id
            where date_part('year', date_from) = #{year.to_i} and status NOT IN (1,5) and bookds_bookings_lines.item_id is not NULL
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
            where date_part('year', date_from) = #{year.to_i} and status NOT IN (1,5) and bookds_bookings_lines_resources.booking_item_reference is not NULL
            order by bookds_bookings_lines_resources.booking_item_reference
          QUERY

          @repository.adapter.select(query)

        end

        #
        # Resources occupation query
        # ---------------------------------------------------------------------------------------------------------
        #
        # NOTE: Do not use directly. Use BookingDataSystem::Booking.resource_urges instead
        # ================================================================================
        #
        # Prepares an SQL query to retrieve the confirmed reservations and stock blockings in a range of dates.
        #
        # == Parameters:
        # date_from::
        #   The reservation starting date
        # date_to::
        #   The reservation ending date
        # options::
        #   A hash with some options in order to filter the results
        #   :mode -> :stock or :product
        #   :reference -> If mode is :stock, the resource reference
        #   :product -> If mode is :product, the category
        #   :include_future_pending_confirmation -> If true it returns future pending of confirmation reservations
        #
        # == Returns:
        #
        # SQL that represents the query
        #
        def resources_occupation_query(from, to, options=nil)

          status_condition = 'b.status NOT IN (1,5)'
          extra_condition = ''
          extra_pr_condition = ''

          unless options.nil?
            if options.has_key?(:include_future_pending_confirmation) and options[:include_future_pending_confirmation]
              status_condition = "(b.status NOT IN (1,5) or (b.status = 1 and b.date_from >= '#{Date.today}'))"
            end
            if options.has_key?(:mode)
              if options[:mode].to_sym == :stock and options.has_key?(:reference)
                extra_condition = "and r.booking_item_reference = '#{options[:reference]}' "
                extra_pr_condition = "and prl.booking_item_reference = '#{options[:reference]}' "
              elsif options[:mode].to_sym == :product and options.has_key?(:product)
                extra_condition = "and l.item_id = '#{options[:product]}' "
                extra_pr_condition = "and prl.booking_item_category = '#{options[:product]}' "
              end
            end
          end

          date_diff_reservations = date_diff('b.date_from', 'b.date_to', 'days')
          date_diff_prereservations = date_diff('pr.date_from', 'pr.date_to', 'days')

          query = <<-QUERY
            SELECT * 
            FROM (
              SELECT r.booking_item_reference,
                   coalesce(r.booking_item_category, l.item_id) as item_id,
                   l.item_id as requested_item_id,
                   b.id,
                   'booking' as origin,
                   b.date_from, b.time_from,
                   b.date_to, b.time_to,
                   #{date_diff_reservations},
                   CONCAT(b.customer_name, ' ', b.customer_surname) as title,
                   CONCAT(coalesce(r.resource_user_name,''), ' ', 
                          coalesce(r.resource_user_surname, ''), ' ', r.customer_height,
                          ' ', r.customer_weight) as detail,                     
                   r.id as id2,
                   b.planning_color,
                   b.notes as notes,
                   CASE 
                     WHEN b.status = 1 THEN 0 
                     WHEN b.status>1 AND b.status<5 THEN 1 
                   END AS confirmed,
                   0 as auto_assigned_item_reference
              FROM bookds_bookings b
              JOIN bookds_bookings_lines l on l.booking_id = b.id
              JOIN bookds_bookings_lines_resources r on r.booking_line_id = l.id
              WHERE ((b.date_from <= '#{from}' and b.date_to >= '#{from}') or 
                 (b.date_from <= '#{to}' and b.date_to >= '#{to}') or 
                 (b.date_from = '#{from}' and b.date_to = '#{to}') or
                 (b.date_from >= '#{from}' and b.date_to <= '#{to}')) and
                  #{status_condition} #{extra_condition} 
              UNION 
              SELECT prl.booking_item_reference, 
                   prl.booking_item_category,
                   prl.booking_item_category as requested_item_id,
                   pr.id,
                   'prereservation' as origin,
                   pr.date_from, pr.time_from,
                   pr.date_to, pr.time_to,
                   #{date_diff_prereservations},
                   pr.title,
                   pr.notes as detail,
                   prl.id as id2,
                   pr.planning_color,
                   pr.notes as notes,
                   1 as confirmed,
                   0 as auto_assigned_item_reference              
              FROM bookds_prereservations pr
              JOIN bookds_prereservation_lines prl on prl.prereservation_id = pr.id
              WHERE ((pr.date_from <= '#{from}' and pr.date_to >= '#{from}') or 
                 (pr.date_from <= '#{to}' and pr.date_to >= '#{to}') or 
                 (pr.date_from = '#{from}' and pr.date_to = '#{to}') or
                 (pr.date_from >= '#{from}' and pr.date_to <= '#{to}')) #{extra_pr_condition}
            ) AS D
            ORDER BY booking_item_reference, date_from
          QUERY

        end


        private

        def text_search_query(b,search_text)
          query = <<-QUERY
            select #{b.*} FROM #{b} 
            where #{b.id} = #{search_text.to_i} or
                  #{b.customer_email} = '#{search_text}' or 
                  #{b.customer_phone} = '#{search_text}' or 
                  #{b.customer_mobile_phone} = '#{search_text}' or
                  unaccent(#{b.customer_surname}) ilike unaccent('#{search_text}%') or 
                  unaccent(#{b.customer_name}) ilike unaccent('#{search_text}%')
          QUERY

        end 

        def first_customer_booking_query(b,params)
          query = <<-QUERY
            select #{b.*} FROM #{b} 
            where trim(lower(#{b.customer_email})) = '#{params[:customer_email]}' and 
                  trim(#{b.customer_phone}) = '#{params[:customer_phone]}' and
                  unaccent(trim(#{b.customer_surname})) ilike unaccent('#{params[:customer_surname]}') and
                  unaccent(trim(#{b.customer_name})) ilike unaccent('#{params[:customer_name]}')
          QUERY

        end 

      end
    end
  end
end