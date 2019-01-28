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

        # --------- Reservation management optimized queries -------------

        def text_search(search_text, limit, offset) #(search_text, offset_order_query={})
          conditions = Conditions::JoinComparison.new('$or', 
                          [Conditions::Comparison.new(:id, '$eq', search_text.to_i),
                           Conditions::Comparison.new(:customer_name, '$like', "%#{search_text}%"),
                           Conditions::Comparison.new(:customer_surname, '$like', "%#{search_text}%"),
                           Conditions::Comparison.new(:customer_email, '$eq', search_text),
                           Conditions::Comparison.new(:customer_phone, '$eq', search_text),
                           Conditions::Comparison.new(:customer_mobile_phone, '$eq', search_text),
                           Conditions::Comparison.new(:external_invoice_number, '$eq', search_text)])
          total = conditions.build_datamapper(BookingDataSystem::Booking).count
          extra_condition = <<-CONDITION
            WHERE b.id = ? or customer_name like ? or customer_surname like ? or customer_email = ? or 
                  customer_phone = ? or customer_mobile_phone = ? or external_invoice_number = ?
          CONDITION
          data = repository.adapter.select(query_reservation_search(limit, offset, extra_condition),
                  search_text.to_i, "%#{search_text}%", "%#{search_text}%", search_text,
                  search_text, search_text, search_text)

          [total, data]
        end

        def text_search_multiple(search_text, limit, offset) #(search_text, offset_order_query={})
          conditions = Conditions::JoinComparison.new('$or', 
                          [Conditions::Comparison.new(:id, '$eq', search_text.to_i),
                           Conditions::Comparison.new(:customer_name, '$like', "%#{search_text}%"),
                           Conditions::Comparison.new(:customer_surname, '$like', "%#{search_text}%"),
                           Conditions::Comparison.new(:customer_email, '$eq', search_text),
                           Conditions::Comparison.new(:customer_phone, '$eq', search_text),
                           Conditions::Comparison.new(:customer_mobile_phone, '$eq', search_text),
                           Conditions::Comparison.new(:external_invoice_number, '$eq', search_text)])
          total = conditions.build_datamapper(BookingDataSystem::Booking).count
          extra_condition = <<-CONDITION
            WHERE b.id = ? or customer_name like ? or customer_surname like ? or customer_email = ? or 
                  customer_phone = ? or customer_mobile_phone = ? or external_invoice_number = ?
          CONDITION
          data = repository.adapter.select(query_reservation_search_multiple(limit, offset, extra_condition),
                  search_text.to_i, "%#{search_text}%", "%#{search_text}%", search_text,
                  search_text, search_text, search_text)

          [total, data]
        end        

        def query_reservation_search(limit, offset, extra_condition='')
              sql = <<-SQL
                SELECT b.id, customer_id, customer_name, customer_surname, date_from, date_to, CAST(status as UNSIGNED) as status, 
                       CAST(payment_status as UNSIGNED) as payment_status, creation_date, created_by_manager, rental_location_code,
                       sales_channel_code, GROUP_CONCAT(CONCAT(bl.item_id)) as item_id
                FROM bookds_bookings b
                JOIN bookds_bookings_lines bl on bl.booking_id = b.id
                #{extra_condition}
                GROUP BY bl.booking_id
                ORDER BY b.id desc
                LIMIT #{limit} OFFSET #{offset}
              SQL
        end

        def query_reservation_search_multiple(limit, offset, extra_condition='')
              sql = <<-SQL
                  SELECT b.id, customer_id, customer_name, customer_surname, date_from, date_to, CAST(status as UNSIGNED) as status, 
                         CAST(payment_status as UNSIGNED) as payment_status, creation_date, created_by_manager, rental_location_code,
                         sales_channel_code, GROUP_CONCAT(CONCAT(bl.item_id, ' (', bl.quantity,' u.)') SEPARATOR ' ') as item_id
                  FROM bookds_bookings b
                  JOIN bookds_bookings_lines bl on bl.booking_id = b.id
                  #{extra_condition}
                  GROUP BY bl.booking_id
                  ORDER BY b.id desc
                  LIMIT #{limit} OFFSET #{offset}
              SQL
        end        

        # --------- Search customers from reservation -------------

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
          BookingDataSystem::Booking.by_sql{ |b| [first_customer_booking_query(b,params)] }.all(order: [:creation_date.desc], offset:0, limit: 1).first
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
            where YEAR(date_from) = #{year.to_i} and status NOT IN (1,5) and bookds_bookings_lines_resources.booking_item_reference is not NULL
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