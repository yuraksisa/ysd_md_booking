module Yito
  module Model
    module Booking
      module Queries

        def self.extended(model)
          model.extend ClassMethods
        end

        module ClassMethods

          # Search customers (and groups by surname, name, phone, email) from bookings
          #
          def customer_search(search_text, options={})
            [query_strategy.count_customer_search(search_text),
             query_strategy.customer_search(search_text, options)]
          end
           
          # Get the first customer booking
          # 
          def first_customer_booking(params)
            query_strategy.first_customer_booking(params)
          end

          #
          # Search booking by text (customer surname, phone, email)
          #          
          def text_search(search_text, offset_order_query={})
             if DataMapper::Adapters.const_defined?(:PostgresAdapter) and repository.adapter.is_a?DataMapper::Adapters::PostgresAdapter
               [query_strategy.count_text_search(search_text),
                query_strategy.text_search(search_text, offset_order_query)]
             else
              conditions = Conditions::JoinComparison.new('$or', 
                              [Conditions::Comparison.new(:id, '$eq', search_text.to_i),
                               Conditions::Comparison.new(:customer_name, '$like', "%#{search_text}%"),
                               Conditions::Comparison.new(:customer_surname, '$like', "%#{search_text}%"),
                               Conditions::Comparison.new(:customer_email, '$eq', search_text),
                               Conditions::Comparison.new(:customer_phone, '$eq', search_text),
                               Conditions::Comparison.new(:customer_mobile_phone, '$eq', search_text),
                               Conditions::Comparison.new(:external_invoice_number, '$eq', search_text)])
            
              total = conditions.build_datamapper(BookingDataSystem::Booking).all.count 
              data = conditions.build_datamapper(BookingDataSystem::Booking).all(offset_order_query) 
              [total, data]
             end
          end

          #
          # Get the number of received reservations
          #
          def count_received_reservations(year)
            query_strategy.count_received_reservations(year)
          end

          #
          # Get the number of pending of confirmation reservations
          #
          def count_pending_confirmation_reservations(year)
            query_strategy.count_pending_confirmation_reservations(year)
          end

          #
          # Get the number of confirmed reservations
          #
          def count_confirmed_reservations(year)
            query_strategy.count_confirmed_reservations(year)
          end 
          
          #
          # Get the products total billing
          #
          def products_billing_total(year)
            query_strategy.products_billing_total(year).first
          end
          
          #
          # Get the extras total billing
          #
          def extras_billing_total(year)
            result = query_strategy.extras_billing_total(year)
            if result.nil?
              value = 0
            else
              value = (result.first || 0)
              if result.size == 2
                value += (result.last || 0)
              end
            end
            return value
          end
          
          #
          # Total amount that should be charged in a period of time
          #
          def total_should_charged(date_from, date_to)
            query = <<-QUERY
                      select sum(b.total_cost)
                      from bookds_bookings b
                      WHERE b.date_from >= ? and date_from <= ? and 
                            b.status NOT IN (1,5)
                    QUERY
            repository.adapter.select(query, date_from, date_to).first        
          end


          #
          # Get the total charged amount for a year
          #
          def total_charged(year)
            data = query_strategy.total_charged(year)
            detail = data.inject({}) do |result, value|
               result.store(value.payment_method, {value: value.total,
                                                   color: "#%06x" % (rand * 0xffffff),
                                                   highlight: "#%06x" % (rand * 0xffffff),
                                                   label: Payments.r18n.t.payment_methods[value.payment_method.to_sym]})
               result
            end

            result = {total: 0, detail: detail}
            data.each { |item| result[:total] += item.total}

            return result
          end
          
          #
          # Get the forecast charged for a period
          #
          def forecast_charged(date_from, date_to)
            result = {total: 0, detail: {}}
            month = date_from.month 
            year = date_from.year
            last_month = date_to.month
            last_year = date_to.year
            until (month == last_month && year == last_year) do
              result[:detail].store("#{year}-#{month.to_s.rjust(2, '0')}", 0)
              if month == 12
                month = 1
                year += 1
              else
                month += 1
              end
            end
            data = query_strategy.forecast_charged(date_from, date_to)
            data.each do |item| 
              result[:total] += item.total
              result[:detail][item.period] += item.total
            end
            return result
          end

          #
          # Get the stock total cost
          #
          def stock_cost_total
            query_strategy.stock_cost_total.first || 0
          end

          #
          # Products billing summary detailed by stock item
          #
          def products_billing_summary_by_stock(year)

            current_year = DateTime.now.year

            # Build the result holder
            total_cost = 0
            stock_items = if current_year == year
                            ::Yito::Model::Booking::BookingItem.all(conditions: {active: true},
                                                                    fields: [:reference, :cost],
                                                                    order: [:category_code, :reference])
                          else
                            BookingDataSystem::Booking.historic_stock(year).map do |item|
                              OpenStruct.new({reference: item.item_reference, cost: 0})
                            end
                          end

            summary = stock_items.inject({}) do |result, item|
              data_holder = {}
              (1..12).each { |item| data_holder.store(item, 0) }
              data_holder.store(:total, 0)
              data_holder.store(:cost, item.cost || 0)
              data_holder.store(:percentage, 0)
              total_cost = total_cost + item.cost unless item.cost.nil?
              result.store(item.reference, data_holder)
              result
            end
            data_holder = {}
            (1..12).each { |item| data_holder.store(item, 0) }
            data_holder.store(:total, 0)
            data_holder.store(:cost, 0)
            data_holder.store(:percentage, 0)
            summary.store(:TOTAL, data_holder)
            # Fill the data
            data = query_strategy.products_billing_summary_by_stock(year)     
            data.each do |data_item|
              if summary.has_key?(data_item.reference)
                # stock
                summary[data_item.reference][data_item.period.to_i] = data_item.total_item_cost
                summary[data_item.reference][:total] += data_item.total_item_cost
                if summary[data_item.reference][:cost] and summary[data_item.reference][:cost] > 0
                  summary[data_item.reference][:percentage] = summary[data_item.reference][:total] /
                                                              summary[data_item.reference][:cost] * 100 
                end
                # total
                summary[:TOTAL][data_item.period.to_i] += data_item.total_item_cost
                summary[:TOTAL][:total] += data_item.total_item_cost
                summary[:TOTAL][:cost] = total_cost
                if summary[:TOTAL][:cost] and summary[:TOTAL][:cost] > 0
                  summary[:TOTAL][:percentage] = summary[:TOTAL][:total] /
                                                 summary[:TOTAL][:cost] * 100 
                end             
              end  
            end

            return summary
          end

          #
          # Extras summary detail
          #
          def extras_billing_summary_by_extra(year)

            # Build the result holder
            extras = ::Yito::Model::Booking::BookingExtra.all(conditions: {active: true}, fields: [:code])
            summary = extras.inject({}) do |result, item|
              data_holder = {}
              (1..12).each { |item| data_holder.store(item, 0) }
              data_holder.store(:total, 0)
              result.store(item.code, data_holder)
              result
            end
            ['entrega_fuera_horas','recogida_fuera_horas','lugar_entrega','lugar_recogida',:TOTAL].each do |concept|
              data_holder = {}
              (1..12).each { |item| data_holder.store(item, 0) }
              data_holder.store(:total, 0)
              summary.store(concept, data_holder)   
            end

            # Fill the data
            data = query_strategy.extras_billing_summary_by_extra(year)   
            data.each do |data_item|
              if summary.has_key?(data_item.extra)
                summary[data_item.extra][data_item.period.to_i] = data_item.total_extra_cost
                summary[data_item.extra][:total] += data_item.total_extra_cost
                # total
                summary[:TOTAL][data_item.period.to_i] += data_item.total_extra_cost
                summary[:TOTAL][:total] += data_item.total_extra_cost
              end  
            end

            return summary
            
          end
          
          #
          # Get the charges between two dates
          # 
          def charges(date_from, date_to)

            if defined?(::Yito::Model::Order) 
              sql = <<-SQL
                select * 
                from (
                  select pc.id, pc.amount, pc.date, pc.payment_method_id, 
                         'booking' as source, bc.booking_id as source_id,
                         'booking' as source_link,
                         b.customer_name as customer_name, b.customer_surname as customer_surname
                  from payment_charges pc
                  join bookds_booking_charges bc on bc.charge_id = pc.id
                  join bookds_bookings b on bc.booking_id = b.id
                  where pc.status = 4
                  union
                  select pc.id, pc.amount, pc.date, pc.payment_method_id, 
                         'order' as source, oc.order_id as source_id,
                         'order' as source_link,
                         o.customer_name as customer_name, o.customer_surname as customer_surname
                  from payment_charges pc
                  join orderds_order_charges oc on oc.charge_id = pc.id
                  join orderds_orders o on oc.order_id = o.id
                  where pc.status = 4
                ) as data_charges
                where data_charges.date >= ? and data_charges.date <= ?
                order by data_charges.date
              SQL
            else
              sql = <<-SQL
                select pc.id, pc.amount, pc.date, pc.payment_method_id, 
                      'booking' as source, bc.booking_id as source_id,
                      'booking' as source_link,
                      b.customer_name as customer_name, b.customer_surname as customer_surname
                from payment_charges pc
                join bookds_booking_charges bc on bc.charge_id = pc.id
                join bookds_bookings b on bc.booking_id = b.id
                where pc.status = 4 and pc.date >= ? and pc.date <= ?
                order by pc.date
              SQL
            end

            charges = repository.adapter.select(sql, date_from, date_to)

            charges.each do |charge|
              charge.payment_method_id = case charge.payment_method_id
                                           when 'redsys256'
                                             BookingDataSystem.r18n.payment_method.payment_redsys256
                                           when 'paypal_standard'
                                             BookingDataSystem.r18n.payment_method.payment_paypal_standard
                                           when 'bank_transfer' 
                                             BookingDataSystem.r18n.payment_method.payment_bank_transfer
                                           when 'credit_card'
                                             BookingDataSystem.r18n.payment_method.payment_credit_card
                                           when 'cash'
                                             BookingDataSystem.r18n.payment_method.payment_cash
                                           else
                                             charge.payment_method_id
                                         end
              if charge.source_link == 'booking'
                charge.source_link = "<a href=\"/admin/booking/bookings/#{charge.source_id}\">#{BookingDataSystem.r18n.booking_model.charge_description(charge.source_id)}</a>"
                charge.source = BookingDataSystem.r18n.booking_model.charge_description(charge.source_id)
              elsif charge.source_link == 'order'
                charge.source_link = "<a href=\"/admin/order/orders/#{charge.source_id}\">Pedido #{BookingDataSystem.r18n.order_model.charge_description(charge.source_id)}</a>"
                charge.source = BookingDataSystem.r18n.order_model.charge_description(charge.source_id)
              end
            end

            return charges

          end

          def count_pickup(date)

            conditions = Conditions::JoinComparison.new('$and', 
                          [Conditions::Comparison.new(:date_from, '$eq', date),
                           Conditions::Comparison.new(:status, '$ne', [:pending_confirmation, :cancelled])])           
            conditions.build_datamapper(BookingDataSystem::Booking).all.count 

          end

          def count_transit(date)

            conditions = Conditions::JoinComparison.new('$and', 
                          [Conditions::Comparison.new(:date_from, '$lte', date),
                            Conditions::Comparison.new(:date_to, '$gte', date),
                           Conditions::Comparison.new(:status, '$ne', [:pending_confirmation, :cancelled])])           
            conditions.build_datamapper(BookingDataSystem::Booking).all.count 

          end

          def count_delivery(date)

            conditions = Conditions::JoinComparison.new('$and', 
                          [Conditions::Comparison.new(:date_to, '$eq', date),
                           Conditions::Comparison.new(:status, '$ne', [:pending_confirmation, :cancelled])])           
            conditions.build_datamapper(BookingDataSystem::Booking).all.count 

          end

          def reservations_by_weekday(year)
            data = query_strategy.reservations_by_weekday(year)
            result = data.inject({}) do |result, value|
               result.store(value.day.to_i.to_s, value.count)
               result
            end
            (0..6).each do |item|
              result.store(item.to_s, 0) unless result.has_key?(item.to_s)
            end
            result
          end

          # Reservations by category
          #
          def reservations_by_category(year)

            data = query_strategy.reservations_by_category(year)
            result = data.inject({}) do |result, value|
               result.store(value.item_id, {value: value.count,
                                            color: "#%06x" % (rand * 0xffffff),
                                            highlight: "#%06x" % (rand * 0xffffff),
                                            label: value.item_id})
               result
            end

            result

          end

          # Reservations by status
          #
          def reservations_by_status(year)
 
            data = query_strategy.reservations_by_status(year)

            result = data.inject({}) do |result, value|
               status = case value.status
                          when 1
                             BookingDataSystem.r18n.t.booking_status.pending_confirmation
                          when 2 
                             BookingDataSystem.r18n.t.booking_status.confirmed
                          when 3 
                             BookingDataSystem.r18n.t.booking_status.in_progress
                          when 4 
                             BookingDataSystem.r18n.t.booking_status.done
                          when 5 
                             BookingDataSystem.r18n.t.booking_status.cancelled
                        end

               color = case value.status
                          when 1
                            'yellow'
                          when 2
                            'green'
                          when 3
                            'blue'
                          when 4
                            'black'
                          when 5
                            'red'

                       end

               result.store(status, {value: value.count,
                                     color: color,
                                     highlight: "#%06x" % (rand * 0xffffff),
                                     label: status})
               result
            end

            result

          end

          # The last 30 days reservations
          #
          def last_30_days_reservations

            months = ['E','F','M','A','My','J','Jl','A','S','O','N','D']

            result = {}
            (0..29).reverse_each do |item|
              today = Date.today - item
              key = "#{today.day}#{months[today.month-1]}"
              result.store(key, 0)
            end

            data = query_strategy.last_30_days_reservations
            data.each do |item|
               today = Date.today - item.period
               key = "#{today.day}#{months[today.month-1]}"
               result.store(key, item.occurrences) if result.has_key?(key)
               result
            end
            result
            
          end


          # Get the products (or categories) that where booked in a year
          #
          def historic_products(year)

            data = query_strategy.historic_products(year)

          end

          #
          # Get the resource with reservation during the period
          #
          def resources_with_reservation(from, to)
            query = <<-QUERY
                select distinct(bookds_bookings_lines_resources.booking_item_reference) as item_reference,
                       bookds_bookings_lines.item_id as item_id,
                       bookds_bookings_lines_resources.booking_item_category as item_category   
                FROM bookds_bookings_lines_resources
                JOIN bookds_bookings_lines on bookds_bookings_lines_resources.booking_line_id = bookds_bookings_lines.id
                JOIN bookds_bookings on bookds_bookings.id = bookds_bookings_lines.booking_id
                where ((bookds_bookings.date_from <= '#{from}' and bookds_bookings.date_to >= '#{from}') or 
                       (bookds_bookings.date_from <= '#{to}' and bookds_bookings.date_to >= '#{to}') or 
                       (bookds_bookings.date_from = '#{from}' and bookds_bookings.date_to = '#{to}') or
                       (bookds_bookings.date_from >= '#{from}' and bookds_bookings.date_to <= '#{to}')) and
                      status NOT IN (1,5) and 
                      bookds_bookings_lines_resources.booking_item_reference is not NULL
                order by bookds_bookings_lines_resources.booking_item_reference
            QUERY

            repository.adapter.select(query)
          end

          #
          # Get the stock that where used in the reservations for a period
          #
          def historic_stock(year)

            data = query_strategy.historic_stock(year)

          end

          #
          # Check the occupation of renting items for a period
          #
          def occupation(from, to, ignore_urge=nil, include_stock=false)
                      
            result = []

            data, detail = resources_occupation(from, to, nil, ignore_urge)
            detail.each do |key, value|
              if include_stock
                result << OpenStruct.new(item_id: key,
                                         stock: value[:stock],
                                         busy: value[:occupation],
                                         resources: value[:available_assignable_stock])
              else
                result << OpenStruct.new(item_id: key,
                                         stock: value[:stock],
                                         busy: value[:occupation])
              end
            end

            return result

          end

          #
          # Check the occupation of extras for a period
          #
          def extras_occupation(from, to)

            result = []
            data, detail = extras_resources_occupation(from, to)
            detail.each do |key, value|
              result << OpenStruct.new(extra_id: key, stock: value[:stock], busy: value[:occupation])
            end
            
            return result  

          end  
          
          #
          # Occupation detail
          #
          # Get the resources of a product (category) that are busy in a date
          #
          # Take into account reservations that have not been assigned
          #
          def occupation_detail(date, product)

            query = <<-QUERY
              SELECT * FROM (
               SELECT l.item_id as item_id, 
                      b.id, 
                      b.customer_name, 
                      b.customer_surname, 
                      b.date_from, 
                      b.time_from, 
                      b.date_to, 
                      b.time_to, 
                      b.customer_email, 
                      b.customer_phone, 
                      b.customer_mobile_phone,
                      r.booking_item_reference, 
                      r.booking_item_category,
                      'booking' as origin
               FROM bookds_bookings_lines as l
               JOIN bookds_bookings as b on b.id = l.booking_id
               JOIN bookds_bookings_lines_resources as r on r.booking_line_id = l.id
               WHERE ((b.date_from <= '#{date}' and b.date_to >= '#{date}') or 
                   (b.date_from <= '#{date}' and b.date_to >= '#{date}') or 
                   (b.date_from = '#{date}' and b.date_to = '#{date}') or
                   (b.date_from >= '#{date}' and b.date_to <= '#{date}')) and
                   b.status NOT IN (1, 5) and 
                   ((l.item_id = '#{product}' and r.booking_item_category IS NULL) or
                    (r.booking_item_category = '#{product}') )
               UNION
               SELECT pr.booking_item_category as item_id,
                      pr.id,
                      pr.title as customer_name,
                      '' as customer_surname,
                      pr.date_from as date_from,
                      pr.time_from as time_from,
                      pr.date_to as date_to,
                      pr.time_to as time_to,
                      '' as customer_email,
                      '' as customer_phone,
                      '' as customer_mobile_phone,
                      prl.booking_item_reference,
                      prl.booking_item_category,
                      'prereservation' as origin
               FROM bookds_prereservations pr
               JOIN bookds_prereservation_lines prl on prl.prereservation_id = pr.id
               WHERE ((pr.date_from <= '#{date}' and pr.date_to >= '#{date}') or 
                   (pr.date_from <= '#{date}' and pr.date_to >= '#{date}') or 
                   (pr.date_from = '#{date}' and pr.date_to = '#{date}') or
                   (pr.date_from >= '#{date}' and pr.date_to <= '#{date}')) and
                   (pr.booking_item_category = '#{product}')
               ) AS d
               ORDER BY booking_item_reference, date_from asc                                     
            QUERY
            occupation = repository.adapter.select(query)
            
          end

          #
          # Resource occupation detail
          #
          # Get the resources of a reference that are busy in a date
          #
          def resource_occupation_detail(date, reference)

            query = <<-QUERY
              SELECT * FROM (
               SELECT l.item_id as item_id, 
                      b.id, 
                      b.customer_name, 
                      b.customer_surname, 
                      b.date_from, 
                      b.time_from, 
                      b.date_to, 
                      b.time_to, 
                      b.customer_email, 
                      b.customer_phone, 
                      b.customer_mobile_phone,
                      b.planning_color,
                      r.booking_item_reference, 
                      r.booking_item_category,
                      'booking' as origin,
                      r.id as id2,
                      CONCAT(r.resource_user_name, ' ', r.resource_user_surname) as resource_1_name,
                      r.customer_height, 
                      r.customer_weight,
                      CONCAT(r.resource_user_name, ' ', r.resource_user_surname) as resource_2_name,
                      r.customer_2_height,
                      r.customer_2_weight,
                      b.comments as comments,
                      r.pax
               FROM bookds_bookings_lines as l
               JOIN bookds_bookings as b on b.id = l.booking_id
               JOIN bookds_bookings_lines_resources as r on r.booking_line_id = l.id
               WHERE ((b.date_from <= '#{date}' and b.date_to >= '#{date}') or 
                   (b.date_from <= '#{date}' and b.date_to >= '#{date}') or 
                   (b.date_from = '#{date}' and b.date_to = '#{date}') or
                   (b.date_from >= '#{date}' and b.date_to <= '#{date}')) and
                   b.status NOT IN (1, 5) and 
                   r.booking_item_reference = '#{reference}'
               UNION
               SELECT prl.booking_item_category as item_id,
                      pr.id,
                      pr.title as customer_name,
                      '' as customer_surname,
                      pr.date_from as date_from,
                      pr.time_from as time_from,
                      pr.date_to as date_to,
                      pr.time_to as time_to,
                      '' as customer_email,
                      '' as customer_phone,
                      '' as customer_mobile_phone,
                      pr.planning_color,
                      prl.booking_item_reference,
                      prl.booking_item_category,
                      'prereservation' as origin,
                      prl.id as id2,
                      '' as resource_1_name,
                      '' as customer_height,
                      '' as customer_weight,
                      '' as resource_2_name,
                      '' as customer_2_height,
                      '' as customer_2_weight,
                      pr.notes as comments,
                      1 as pax
               FROM bookds_prereservations pr
               JOIN bookds_prereservation_lines prl on prl.prereservation_id = pr.id
               WHERE ((pr.date_from <= '#{date}' and pr.date_to >= '#{date}') or 
                   (pr.date_from <= '#{date}' and pr.date_to >= '#{date}') or 
                   (pr.date_from = '#{date}' and pr.date_to = '#{date}') or
                   (pr.date_from >= '#{date}' and pr.date_to <= '#{date}')) and
                   pr.booking_item_reference = '#{reference}'
               ) AS d
               ORDER BY booking_item_reference, date_from asc                                     
            QUERY
            occupation = repository.adapter.select(query)
            
          end

          #
          # Resource occupation detail
          #
          # Get the resources of a reference that are busy in a date
          #
          def resource_origin_detail(origin, id)

            if origin == 'booking'
              query = <<-QUERY
                   SELECT l.item_id as item_id, 
                        b.id, 
                        b.customer_name, 
                        b.customer_surname, 
                        b.date_from, 
                        b.time_from, 
                        b.date_to, 
                        b.time_to, 
                        b.customer_email, 
                        b.customer_phone, 
                        b.customer_mobile_phone,
                        b.planning_color,
                        r.booking_item_reference, 
                        r.booking_item_category,
                        'booking' as origin,
                        r.id as id2,
                        CONCAT(r.resource_user_name, ' ', r.resource_user_surname) as resource_1_name,
                        r.customer_height, 
                        r.customer_weight,
                        CONCAT(r.resource_user_name, ' ', r.resource_user_surname) as resource_2_name,
                        r.customer_2_height,
                        r.customer_2_weight,
                        b.comments as comments,
                        r.pax
                   FROM bookds_bookings_lines as l
                   JOIN bookds_bookings as b on b.id = l.booking_id
                   JOIN bookds_bookings_lines_resources as r on r.booking_line_id = l.id
                   WHERE r.id = #{id}
              QUERY
            else
              query = <<-QUERY
                  SELECT prl.booking_item_category as item_id,
                          pr.id,
                          pr.title as customer_name,
                          '' as customer_surname,
                          pr.date_from as date_from,
                          pr.time_from as time_from,
                          pr.date_to as date_to,
                          pr.time_to as time_to,
                          '' as customer_email,
                          '' as customer_phone,
                          '' as customer_mobile_phone,
                          pr.planning_color,
                          prl.booking_item_reference,
                          prl.booking_item_category,
                          'prereservation' as origin,
                          prl.id as id2,
                          '' as resource_1_name,
                          '' as customer_height,
                          '' as customer_weight,
                          '' as resource_2_name,
                          '' as customer_2_height,
                          '' as customer_2_weight,
                          pr.notes as comments,
                          1 as pax
                  FROM bookds_prereservations pr
                  JOIN bookds_prereservation_lines prl on prl.prereservation_id = pr.id
                  WHERE pr.id = #{id}
              QUERY
            end
            
            resource_origin_detail = repository.adapter.select(query)

          end

          # Get the daily percentage occupation in a period of time 
          #
          def monthly_occupation(month, year, category=nil)

            current_year = DateTime.now.year

            from = Date.civil(year, month, 1)
            to = Date.civil(year, month, -1)
            product_family = ::Yito::Model::Booking::ProductFamily.get(SystemConfiguration::Variable.get_value('booking.item_family'))

            # Get products stocks
            if current_year == year
              conditions = category.nil? ? {} : {code: category}
              categories = ::Yito::Model::Booking::BookingCategory.all(conditions: conditions.merge({active: true}), fields: [:code, :stock])
              stocks = categories.inject({}) do |result, item|
                         result.store(item.code, item.stock)
                         result
                       end
            else
              categories = BookingDataSystem::Booking.historic_products(year).map do |item|
                              OpenStruct.new({code: item, stock: 0})
                           end
              stocks = categories.inject({}) do |result, item|
                          stock = if h_b_c = ::Yito::Model::Booking::BookingCategoryHistoric.first(category_code: item.code, year: year)
                                    h_b_c.stock
                                  else
                                    if b_c = ::Yito::Model::Booking::BookingCategory.get(item.code)
                                      b_c.stock
                                    else
                                      0
                                    end
                                  end
                          result.store(item.code, stock)
                          result
                       end
            end
            stocks.store(:total, stocks.values.inject(0) {|result, item| result+=item })
            
            # Build products occupation
            cat_occupation =  categories.map{|item| item.code}.concat([:total]).inject({}) do |result, item|
                                days_hash = {}
                                (1..(to.day)).each do |day|
                                  days_hash.store(day, {items:[], occupation:0, occupied: 0, total: stocks[item], percentage:0})
                                end
                                days_hash.store(:total, {occupation:0, occupied: 0, total: 0, percentage:0})
                                result.store(item, days_hash)
                                result
                              end

            # Query bookings for the period
            query = occupation_query(from, to)

            reservations = repository.adapter.select(query)
            
            # Fill products occupation
            reservations.each do |reservation|
              date_from = reservation.date_from
              date_to = reservation.date_to
              calculated_from = date_from.month < month ? 1 : date_from.day
              calculated_to = date_to.month > month ? to.day : date_to.day 
              (calculated_from..calculated_to).each do |index|
                unless reservation.booking_item_reference.nil?
                  unless cat_occupation[reservation.item_id][index][:items].include?(reservation.booking_item_reference)
                    cat_occupation[reservation.item_id][index][:items] << reservation.booking_item_reference
                  end
                end
                cat_occupation[reservation.item_id][index][:occupied] += reservation.quantity if cat_occupation.has_key?(reservation.item_id)
              end
            end

            # Calculate occupation representation and percentage
            cat_occupation.each do |key, value|  
              value.each do |day, occupation|
                if cat_occupation[key][day][:total] > 0
                  cat_occupation[key][day][:occupation] = "#{cat_occupation[key][day][:occupied]}/#{cat_occupation[key][day][:total]}"
                  cat_occupation[key][day][:percentage] = (cat_occupation[key][day][:occupied].to_f / cat_occupation[key][day][:total].to_f * 100).round
                else
                  cat_occupation[key][day][:occupation] = '-'
                  cat_occupation[key][day][:percentage] = 0
                end
              end
            end

            # Calculate totals
            # TOTAL column
            cat_occupation.each do |key, value|
              value.each do |day, occupation|
                next if day == :total
                cat_occupation[key][:total][:occupied] += occupation[:occupied]
                cat_occupation[key][:total][:total] += occupation[:total]
                if cat_occupation[key][:total][:total] > 0
                  cat_occupation[key][:total][:percentage] = (cat_occupation[key][:total][:occupied].to_f / cat_occupation[key][:total][:total].to_f * 100).round
                end
              end
            end

            # TOTAL row
            ((from.day)..(to.day)).each do |day|
              cat_occupation.each do |key, value|
                next if key == :total
                cat_occupation[:total][day][:occupied] += value[day][:occupied]
                if cat_occupation[:total][day][:total] > 0
                  cat_occupation[:total][day][:percentage] = (cat_occupation[:total][day][:occupied].to_f / cat_occupation[:total][day][:total].to_f * 100).round
                end
              end
            end

            ((from.day)..(to.day)).each do |day|
              cat_occupation[:total][:total][:occupied] += cat_occupation[:total][day][:occupied]
              if cat_occupation[:total][:total][:total] > 0
                 cat_occupation[:total][:total][:percentage] = (cat_occupation[:total][:total][:occupied].to_f / cat_occupation[:total][:total][:total].to_f * 100).round
              end
            end

            cat_occupation

          end
          
          #
          # Get the assignable resources in a date range (including reservations and prereservations)
          #
          #
          def resource_urges(date_from, date_to, options=nil)
            query = resources_occupation_query(date_from, date_to, options)
            resource_occupations = repository.adapter.select(query)
          end


          #
          # Get the extras urges in a date range (including reservations)
          # 
          def extras_urges(date_from, date_to)
            query = extras_occupation_query(date_from, date_to)
            extras_occupations = repository.adapter.select(query) 
          end

          #
          # Get the resources occupation to assign stock
          #
          # date_from   : The reservation date_from
          # date_to     : The reservation date_to
          # category    : The requested category (or nil for all categories)
          # ignore_urge : Ignore urge
          #
          # Return an array with two elements
          #
          #  - First  : stock_detail. (Hash) The stock, availability and assigned sources
          #
          #             - The key is the stock resource id
          #             - The value is a Hash with :
          #                 :category        : The product category
          #                 :own_property    : The product belongs to the company
          #                 :assignable      : The product allow assignation
          #                 :available       : Boolean that says the is available or not
          #                 :detail          : Assigned reservations
          #                 :estimation      : Automatically assigned reservations
          #                 :real_stock      : It's real stock or dummy to manage not defined resources
          #
          #  - Second : category_occupation. (Hash) The products categories and its occupation
          #
          #             - The key is the category code and 
          #             - The value is a Hash with :
          #                 :stock               : # of stock in the category
          #                 :occupation [urges]  : # of occupied stock in the category (taking into account automatically assignation)
          #                 :occupation_assigned : # of assigned urges
          #                 :available_stock     : # stock not assigned [id's of the items]
          #                 :available_assignable_stock : # stock not assigned and available [id's of the items]
          #                 :assignation_pending : #
          # 
          #
          def resources_occupation(date_from, date_to, category=nil, ignore_urge=nil)
              
            hours_cadency = SystemConfiguration::Variable.get_value('booking.assignation_hours_return_pickup','2')

            #
            # 1. Build the required_categories
            #
            #    - The key is the category_code
            #    - The valus is a Hash
            #
            #        :total                           # of resource urges for this category (that has not been already assigned) [AFTER AUTO REASSIGN]
            #        :assignation_pending             List of reservations/prereservations that requires the item [AFTER AUTO REASSIGN]
            #        :original_total                  # of resource urges for this category [BEFORE AUTO REASSIGN] 
            #        :original_assignation_pending    List of reservations/prereservations that requires the item [BEFORE AUTO REASSIGN]
            #        :reassign_total                  # of resource urges for this category [HAVE BEEN AUTO REASSIGNED]
            #        :reassigned_assignation_pending  List of reservations/prereservations that requires the item [HAVE BEEN AUTO REASSIGNED]
            #        :stock                           is a Hash
            #                                           - The key the is the stock item reference
            #                                           - The value is an array with the assigned (+ automatically assigned) reservations
            #           
            categories = ::Yito::Model::Booking::BookingCategory.all(conditions: {active: true}, fields: [:code, :stock], order: [:code])   

            required_categories = categories.inject({}) do |result, cat|
              result.store(cat.code, {category_stock: cat.stock,
                                      total: 0,
                                      assignation_pending: [],
                                      original_total: 0,
                                      original_assignation_pending: [],
                                      reassigned_total: 0, 
                                      reassigned_assignation_pending: [],
                                      stock: {}})
              result
            end

            # 
            # 2. Build the stock detail structure
            #                
            stock_items = if category 
                      ::Yito::Model::Booking::BookingItem.all(:conditions => {category_code: category, active: true },
                                                              :order => [:planning_order, :category_code, :reference])
                    else
                      ::Yito::Model::Booking::BookingItem.all(:conditions => {active: true },
                                                              :order => [:planning_order, :category_code, :reference])
                    end

            stock_detail = {}
            stock_items.each do |stock_item|
              # Register the item in the stock_detail hash
              stock_detail.store(stock_item.reference, {category: stock_item.category_code,
                                                        own_property: stock_item.own_property,
                                                        assignable: stock_item.assignable,
                                                        available: true,
                                                        real_stock: true,
                                                        detail: [],
                                                        estimation: []})
              # Register the item in the required_categories hash
              if required_categories.has_key?(stock_item.category_code)
                required_categories[stock_item.category_code][:stock].store(stock_item.reference, [])
              end
            end

            # 2.b create dummy resources (when category stock does not match stock items)
            required_categories.each do |category_code, category_value|
               if category_value[:category_stock] > category_value[:stock].size
                 ((category_value[:stock].size+1)..category_value[:category_stock]).each do |idx|
                   stock_id = "DUMMY-#{category_code}-#{idx}"
                   # Add dummy resource to the category stock detail
                   category_value[:stock].store(stock_id, [])
                   # Add dummy resource to the stock detail
                   stock_detail.store(stock_id, {category: category_code,
                                               own_property: true,
                                               assignable: true,
                                               available: true,
                                               real_stock: false,
                                               detail: [],
                                               estimation: []})
                 end
               end
            end

            #
            # 3. Fill with reservations urges 
            #
            #
            # Get the resources urges (that corresponds to reservations that must be served in the period)
            #
            resource_urges = resource_urges(date_from, date_to)
            resource_urges.each do |resource_urge|
              resource_urge.instance_eval { class << self; self end }.send(:attr_accessor, :preassigned_item_reference)
              if resource_urge.booking_item_reference # Assigned stock resource
                if stock_detail.has_key?(resource_urge.booking_item_reference)
                  stock_detail[resource_urge.booking_item_reference][:available] = false
                  stock_detail[resource_urge.booking_item_reference][:detail] << resource_urge
                  # Append the resource_urge (of the assigned stock) to the category to manage the already assigned resources
                  if required_categories[resource_urge.item_id][:stock].has_key?(resource_urge.booking_item_reference)
                    required_categories[resource_urge.item_id][:stock][resource_urge.booking_item_reference] << resource_urge
                  else
                    required_categories[resource_urge.item_id][:stock][resource_urge.booking_item_reference] = [resource_urge]
                  end  
                end
              else # Not assigned resource stock
                # Ignore urge
                if (!ignore_urge.nil? and ignore_urge.is_a?(Hash) and
                    ignore_urge.has_key?(:origin) and ignore_urge.has_key?(:id) and
                    ignore_urge[:origin] == resource_urge.origin and
                    ignore_urge[:id] == resource_urge.id)
                  p "Ignored urge: #{ignore_urge.inspect}"
                else
                  if required_categories.has_key?(resource_urge.item_id)
                    required_categories[resource_urge.item_id][:total] += 1
                    required_categories[resource_urge.item_id][:assignation_pending] << resource_urge
                  end
                end

              end
            end

            #
            # 4. Try to automatically assign stock to assignation pending (resource_urges)
            #
            required_categories.each do |required_category_key, required_category_value|

              required_categories[required_category_key][:original_total] = required_categories[required_category_key][:total]
              required_categories[required_category_key][:original_assignation_pending] = required_categories[required_category_key][:assignation_pending].clone

              # Clones the assignation pending resource urges (because we are going to manipulate it)
              assignation_pending_sources = required_category_value[:assignation_pending].clone
              p "Checking assignation_pending. Category=#{required_category_key}.Total pending:#{assignation_pending_sources.size}"
              assignation_pending_sources.each_with_index do |assignation_pending_source, index|
                p "assignation_pending_source(#{index}):#{assignation_pending_source.inspect}"
                # Build date from and date to
                pending_date_from = parse_date_time_from(assignation_pending_source.date_from,
                                                         assignation_pending_source.time_from)
                pending_date_to = parse_date_time_to(assignation_pending_source.date_to,
                                                     assignation_pending_source.time_to)
                # Search for candidates (from the category's stock)
                candidates = required_category_value[:stock].select do |item_reference, item_reference_assigned_reservations|
                               if stock_detail[item_reference][:assignable]
                                 not_overlapped = item_reference_assigned_reservations.all? do |item_reference_assigned_reservation|
                                   assigned_date_from = parse_date_time_from(item_reference_assigned_reservation.date_from,
                                                                             item_reference_assigned_reservation.time_from)
                                   assigned_date_to = parse_date_time_from(item_reference_assigned_reservation.date_to,
                                                                           item_reference_assigned_reservation.time_to)
                                   pending_date_to < (assigned_date_from - Rational(hours_cadency,24)) ||
                                   pending_date_from > (assigned_date_to + Rational(hours_cadency,24))
                                 end
                                 if not_overlapped
                                   free_assignations=resource_urges(assignation_pending_source.date_from,
                                                  assignation_pending_source.date_to,
                                                  {mode: :stock, reference: item_reference}).all? do |element|
                                     element_date_from = parse_date_time_from(element.date_from, element.time_from)
                                     element_date_to = parse_date_time_from(element.date_to, element.time_to)
                                     pending_date_to < (element_date_from - Rational(hours_cadency,24)) ||
                                     pending_date_from > (element_date_to + Rational(hours_cadency,24))
                                   end
                                   p "checked(#{index}).Reference:#{item_reference}.possible=#{free_assignations}-from:#{assignation_pending_source.date_from.strftime('%Y-%m-%d')}--to:#{assignation_pending_source.date_to.strftime('%Y-%m-%d')}"
                                   free_assignations
                                 else
                                   false # Reservations in requested date range overlapped
                                 end
                               else
                                 false # Resource is not assignable
                               end
                             end
                # Candidates found => pre-assignation
                if candidates.size > 0
                  candidate_item_reference = candidates.keys.first
                  # Apply reassignation
                  required_category_value[:total] -= 1
                  required_category_value[:assignation_pending].delete(assignation_pending_source)
                  # Holds for history
                  required_category_value[:reassigned_total] += 1
                  required_category_value[:reassigned_assignation_pending] << assignation_pending_source
                  # Append the assignation pending to the stock assigned 
                  required_category_value[:stock][candidate_item_reference] << assignation_pending_source
                  required_category_value[:stock][candidate_item_reference].sort! {|x,y| x.date_from <=> y.date_from }
                  if stock_detail.has_key?(candidate_item_reference)
                    stock_detail[candidate_item_reference][:estimation] << assignation_pending_source
                  end 
                  assignation_pending_source.preassigned_item_reference = candidate_item_reference
                end             

              end 

            end

            #p "==================================================="
            #p "stock detail : #{stock_detail.inspect}"
            #p "==================================================="
            #p "required categories: #{required_categories.inspect}"
            #p "==================================================="
            
            category_occupation = {}
            
            request_date_from =parse_date_time_from(date_from)
            request_date_to = parse_date_time_to(date_to)

            required_categories.each do |required_category_key, required_category_value|

              stock = required_category_value[:category_stock]
              occupation = (stock_detail.select {|k,v| v[:category] == required_category_key && (!v[:detail].empty? || !v[:estimation].empty?) }).keys.count
              occupation_assigned = (stock_detail.select {|k,v| v[:category] == required_category_key && !v[:detail].empty? }).keys.count
              available_stock = (stock_detail.select {|k,v| v[:category] == required_category_key && v[:real_stock] && v[:detail].empty? && v[:estimation].empty?}).keys
              available_assignable_stock =  (stock_detail.select {|k,v| v[:category] == required_category_key && v[:real_stock] && v[:assignable] && v[:detail].empty? && v[:estimation].empty?}).keys
              automatically_preassigned_stock = (stock_detail.select {|k,v| v[:category] == required_category_key && !v[:estimation].empty? }).keys
              available_assignable_resource = (stock_detail.select do
                                                  |k,v| v[:category] == required_category_key && v[:detail].empty? && v[:estimation].empty? && stock_detail[k][:assignable]
                                               end).keys.count
              # If there is not stock, check if there are available assignable resources in order to admit reservations
              stock = occupation + available_assignable_resource if (stock <= occupation)

              category_occupation.store(required_category_key,
                                       {stock: stock, # Number that represents category total stock (take into account available assignable resources)
                                        occupation: occupation, # Number that represents the category total occupation
                                        occupation_assigned: occupation_assigned, # Number that represents the category occupation that have been assigned
                                        available_stock: available_stock, # Array of available stock item references
                                        available_assignable_stock: available_assignable_stock, # Array of available and assignable stock item references
                                        automatically_preassigned_stock: automatically_preassigned_stock, # Array of automatically pre-assigned stock item references
                                        assignation_pending: required_category_value[:original_assignation_pending]})

            end

            #p "======================================"
            #p "CATEGORY OCCUPATION : #{category_occupation.inspect}"
            #p "======================================"

            return [stock_detail, category_occupation]

          end
          
          # Get the extras occupation to determinate the availability
          #
          # Return a hash with the extras category and its occupation
          #
          #  - The extras categories and its occupation
          #
          #             - The key is the category code and 
          #             - The value is a Hash with :
          #                 :stock               : # of stock of the extra
          #                 :occupation          : # of occupied stock of the extra (taking into account automatically assignation)
          #                 :available_stock     : # stock not assigned [id's of the items]
          #                 :assignation_pending : # assignation pending
          # 
          #
          def extras_resources_occupation(date_from, date_to, category=nil)

            hours_cadency = SystemConfiguration::Variable.get_value('booking.hours_cadence','2').to_f / 24


            # 1. Build the required_extras
            #
            #    - The key is the extra_code
            #    - The valus is a Hash
            #
            #        :total                           # of resource urges for this extra (that has not been already assigned) [AFTER AUTO REASSIGN]
            #        :assignation_pending             List of reservations that requires the extra [AFTER AUTO REASSIGN]
            #        :original_total                  # of resource urges for this extra [BEFORE AUTO REASSIGN] 
            #        :original_assignation_pending    List of reservations that requires the item [BEFORE AUTO REASSIGN]
            #        :reassign_total                  # of resource urges for this extra [HAVE BEEN AUTO REASSIGNED]
            #        :reassigned_assignation_pending  List of reservations that requires the extra [HAVE BEEN AUTO REASSIGNED]
            #        :stock                           is a Hash
            #                                           - The key the is the extra item reference
            #                                           - The value is an array with the assigned (+ automatically assigned) reservations
            #           
            extras = ::Yito::Model::Booking::BookingExtra.all(conditions: {active: true}, fields: [:code, :max_quantity], order: [:code])   

            required_extras = extras.inject({}) do |result, extra|
              result.store(extra.code, {category_stock: extra.stock,
                                        total: 0,
                                        assignation_pending: [],
                                        original_total: 0,
                                        original_assignation_pending: [],
                                        reassigned_total: 0, 
                                        reassigned_assignation_pending: [],
                                        stock: {}})
              result
            end

            # 
            # 2. Build the stock detail structure
            #
            stock_detail = {}

            # 2.b create dummy resources (has has not stock items)
            required_extras.each do |extra_code, extra_value|
               if extra_value[:category_stock] > extra_value[:stock].size
                 ((extra_value[:stock].size+1)..extra_value[:category_stock]).each do |idx|
                   stock_id = "DUMMY-#{extra_code}-#{idx}"
                   # Add dummy resource to the category stock detail
                   extra_value[:stock].store(stock_id, [])
                   # Add dummy resource to the stock detail
                   stock_detail.store(stock_id, {category: extra_code,
                                                 available: true,
                                                 estimation: []})
                 end
               end
            end

            #
            # 3. Fill with reservations urges 
            #
            extras_urges = extras_urges(date_from, date_to)
            extras_urges.each do |extra_urge|
              extra_urge.instance_eval { class << self; self end }.send(:attr_accessor, :preassigned_item_reference)
              # Not assigned resource stock 
              if required_extras.has_key?(extra_urge.extra_id)
                required_extras[extra_urge.extra_id][:total] += 1
                required_extras[extra_urge.extra_id][:assignation_pending] << extra_urge
              end
            end

            #
            # 4. Try to automatically assign stock to assignation pending (extras_urges)
            #
            required_extras.each do |required_extra_key, required_extra_value|

              required_extras[required_extra_key][:original_total] = required_extras[required_extra_key][:total]
              required_extras[required_extra_key][:original_assignation_pending] = required_extras[required_extra_key][:assignation_pending].clone

              # Clones the assignation pending resource urges (because we are going to manipulate it)
              assignation_pending_sources = required_extra_value[:assignation_pending].clone
              assignation_pending_sources.each do |assignation_pending_source|
                # Search stock items candidates
                candidates = required_extra_value[:stock].select do |item_reference, item_reference_assigned_reservations|
                               item_reference_assigned_reservations.all? do |assigned|
                                 assign_pend_d_f = parse_date_time_from(assignation_pending_source.date_from, assignation_pending_source.time_from)
                                 assign_pend_d_t = parse_date_time_to(assignation_pending_source.date_to, assignation_pending_source.time_to)
                                 assigned_d_f = parse_date_time_from(assigned.date_from, assigned.time_from)
                                 assigned_d_t = parse_date_time_from(assigned.date_to, assigned.time_to)
                                 assignation_pending_source.date_to < (assigned.date_from - hours_cadency) || assignation_pending_source.date_from > (assigned.date_to + hours_cadency)
                               end
                             end  
            
                if candidates.size > 0
                  candidate_item_reference = candidates.keys.first
                  # Apply reassignation
                  required_extra_value[:total] -= 1
                  required_extra_value[:assignation_pending].delete(assignation_pending_source)
                  # Holds for history
                  required_extra_value[:reassigned_total] += 1
                  required_extra_value[:reassigned_assignation_pending] << assignation_pending_source
                  # Append the assignation pending to the stock assigned 
                  required_extra_value[:stock][candidate_item_reference] << assignation_pending_source
                  required_extra_value[:stock][candidate_item_reference].sort! {|x,y| x.date_from <=> y.date_from }
                  if stock_detail.has_key?(candidate_item_reference)
                    stock_detail[candidate_item_reference][:estimation] << assignation_pending_source
                  end 
                  assignation_pending_source.preassigned_item_reference = candidate_item_reference
                  stock_detail[candidate_item_reference][:available] = false
                end             

              end 

            end
            #
            #
            #
            extras_occupation = {}
            
            request_date_from =parse_date_time_from(date_from)
            request_date_to = parse_date_time_to(date_to)

            required_extras.each do |required_extra_key, required_extra_value|

              stock = required_extra_value[:category_stock]
              occupation = (stock_detail.select {|k,v| v[:category] == required_extra_key && (!v[:estimation].empty?) }).keys.count
              available_stock = (stock_detail.select {|k,v| v[:category] == required_extra_key && v[:estimation].empty? }).keys
              automatically_preassigned_stock = (stock_detail.select {|k,v| v[:category] == required_extra_key && !v[:estimation].empty? }).keys
              available_assignable_resource = (stock_detail.select do
                                                  |k,v| v[:category] == required_extra_key && v[:estimation].empty? && stock_detail[k][:assignable]
                                               end).keys.count
              # If there is not stock, check if there are available assignable resources in order to admit reservations
              stock = occupation + available_assignable_resource if (stock <= occupation)

              extras_occupation.store(required_extra_key,
                                       {stock: stock,
                                        occupation: occupation,
                                        available_stock: available_stock ,
                                        automatically_preassigned_stock: automatically_preassigned_stock,
                                        assignation_pending: required_extra_value[:assignation_pending]})

            end

            return [stock_detail, extras_occupation]

          end

          #
          # Get planning resource
          #
          def planning_resources(date_from, date_to, options=nil)

            current_year = DateTime.now.year
            references = []
            references_hash = {}

            # Current stock

            if !options.nil? and options[:mode] == :stock and options.has_key?(:reference) # Reference
              references << options[:reference]
              if item = ::Yito::Model::Booking::BookingItem.get(options[:reference])
                references_hash.store(item.reference, item.category_code)
              else
                references_hash.store(options[:reference], nil)
              end
            elsif !options.nil? and options[:mode] == :product and options.has_key?(:product) # Product references
              ::Yito::Model::Booking::BookingItem.all(
                  :conditions => {category_code: options[:product], active: true},
                  :fields => [:reference, :category_code],
                  :order =>  [:planning_order, :category_code, :reference]).each do |item|
                references << item.reference
                references_hash.store(item.reference, item.category_code)
              end
            else # All
              ::Yito::Model::Booking::BookingItem.all(
                  :conditions => {active: true},
                  :fields => [:reference, :category_code],
                  :order =>  [:planning_order, :category_code, :reference]).each do |item|
                references << item.reference
                references_hash.store(item.reference, item.category_code)
              end
            end

            # Historic stock (from assigned reservations)

            historic_resources = BookingDataSystem::Booking.resources_with_reservation(date_from, date_to)
            historic_resources_hash = historic_resources.inject({}) do |result, item|
              result.store(item.item_reference, item.item_category) unless result.has_key?(item.item_reference)
              result
            end

            # Append the historic stock

            if !options.nil? and options[:mode] == :product and options.has_key?(:product) # Product
              historic_resources_hash.each do |key, value|
                if value == options[:product]
                  references << key unless references.include?(key)
                  references_hash.store(key, value) unless references_hash.has_key?(key)
                end
              end
            else
              historic_resources.each do |item|
                references << item.item_reference unless references.include?(item.item_reference)
              end
              historic_resources_hash.each do |key, value|
                references_hash.store(key, value) unless references_hash.has_key?(key)
              end
            end

            # Historic stock blocking (from stock blocking)

            #p "references: #{references_hash.inspect}"

            return [references, references_hash]
          end

          #
          # Get the planning detail
          #
          def planning(date_from, date_to, options=nil)

            # 1. Get the stock
            references, references_hash = planning_resources(date_from, date_to, options)

            # 2. Get the reservations
            query = resources_occupation_query(date_from, date_to, options)
            resource_occupations = repository.adapter.select(query)
            resource_occupations.each do |item|
              item.date_from = item.date_from.strftime('%Y-%m-%d')
              item.date_to = item.date_to.strftime('%Y-%m-%d')
            end

            {references: references_hash, result: resource_occupations}
          end

          #
          # Get the planning detail
          #
          def planning_table(date_from, date_to, options=nil)

            # 1. Get the stock 
            references, references_hash = planning_resources(date_from, date_to, options)

            # 2. Build the result structure
            result = {}
            days = (date_to - date_from).to_i
            (0..days).each do |d|
              date = date_from + d 
              detail = {}
              references.each do |reference|
                detail.store(reference, {total: 0, detail: [], summary: nil, reservation_ids: nil, prereservation_ids: nil})
              end              
              result.store(date.strftime('%Y-%m-%d'), detail)
            end         

            # 3. Fill the result with reservations
            query = resources_occupation_query(date_from, date_to)
            resource_occupations = repository.adapter.select(query)

            resource_occupations.each do |resource_occupation|
              (0..resource_occupation.days).each do |day|
                key = (resource_occupation.date_from + day).strftime('%Y-%m-%d')
                reference = resource_occupation.booking_item_reference
                if result.has_key?(key) and result[key].has_key?(reference)
                  item = result[key][reference]
                  item[:total] += 1
                  item[:detail] << resource_occupation.to_h
                  summary = resource_occupation.origin == 'booking' ? 'R:' : 'PR:'
                  summary << ' '
                  summary << resource_occupation.id.to_s
                  summary << ' '
                  summary << resource_occupation.date_from.strftime('%d-%m-%Y')
                  summary << ' '
                  summary << resource_occupation.time_from
                  summary << ' '
                  summary << resource_occupation.date_to.strftime('%d-%m-%Y')
                  summary << ' '
                  summary << resource_occupation.time_to
                  summary << ' '
                  summary << resource_occupation.title
                  if item[:summary] != nil
                    item[:summary] << '&#013;'
                    item[:summary] << summary
                  else
                    item[:summary] = summary
                  end
                  if resource_occupation.origin == 'booking'
                    if item[:reservation_ids] != nil
                      item[:reservation_ids] << ' '
                      item[:reservation_ids] << resource_occupation.id2.to_s
                    else
                      item[:reservation_ids] = resource_occupation.id2.to_s 
                    end                  
                  else
                    if item[:prereservation_ids] != nil
                      item[:prereservation_ids] << ' '
                      item[:prereservation_ids] << resource_occupation.id2.to_s
                    else
                      item[:prereservation_ids] = resource_occupation.id2.to_s 
                    end
                  end
                end
              end 
            end
            
            # 4. Prepare the response
            return {references: references_hash, result: result}

          end

          # Get the hourly percentage occupation in a day
          #
          def daily_occupation(day)
            
            categories = ::Yito::Model::Booking::BookingCategory.all(fields: [:code, :stock])
            
            stocks = categories.inject({}) do |result, item|
                       result.store(item.code, item.stock)
                       result
                     end

            scheduler_start_time = Time.parse(SystemConfiguration::Variable.get_value('booking.scheduler_start_time', '07:00'))
            scheduler_end_time = Time.parse(SystemConfiguration::Variable.get_value('booking.scheduler_finish_time', '23:30'))

            scheduler = categories.inject({}) do |result, item|
                          hours_hash = {} 
                          (0..23).each do |hour|
                            [0,30].each do |minute|
                              time = "#{hour.to_s.rjust(2,'00')}:#{minute.to_s.rjust(2,'00')}"
                              hours_hash.store(time, 0) if Time.parse(time) >= scheduler_start_time and Time.parse(time) <= scheduler_end_time
                            end
                          end
                          result.store(item.code, hours_hash)
                          result
                        end

            query = <<-QUERY
               select bl.item_id, bl.quantity, b.date_from, b.time_from, b.date_to, b.time_to
               from bookds_bookings_lines bl join bookds_bookings b on bl.booking_id = b.id 
               where date_from >= '#{day}' and date_from < '#{day+1}' and b.status <> 5
               order by bl.item_id, date_from
            QUERY

            last_time = SystemConfiguration::Variable.get_value('booking.scheduler_finish_time')

            occupation = repository.adapter.select(query)

            occupation.each do |item|
              hours = hour_array(item.time_from, item.time_to, 0.5, ['00','30'], last_time)
              hours.each do |hour|
                scheduler[item.item_id][hour] += item.quantity
              end
            end

            scheduler.each do |key, value|  
              value.each do |hour, occupation| 
                scheduler[key][hour] = "#{scheduler[key][hour]}/#{stocks[key]}"
              end
            end            

            scheduler

          end 
          
          #
          # Get the reservations pending of assignation
          #
          # Note: We can assign reservations starting or ending up to 7 days before today
          def pending_of_assignation

            BookingDataSystem::Booking.by_sql{ |b| [select_pending_of_assignation(b)] }.all(order: :date_from) 

          end

          #
          # Get the detail of the reservations that involve a resource
          #
          def resource_reservations(date_from, date_to, stock_plate)

             BookingDataSystem::Booking.by_sql { |b| 
               [select_resource_reservations(b), stock_plate, 
                 date_from, date_from, 
                 date_to, date_to,
                 date_from, date_to,
                 date_from, date_to ] }.all(order: :date_from) 

          end

          #
          # Max external invoice number
          #
          def max_external_invoice_number
            query = <<-QUERY
               select max(external_invoice_number)
               from bookds_bookings
            QUERY

            repository.adapter.select(query).first
          end
          
          #
          # Pickup in a date
          #
          def pickup_list(from, to, rental_location_code=nil, include_journal=false)

            # Get reservations

            conditions = {:date_from.gte => from,
                          :date_from.lte => to,
                          :status => [:confirmed, :in_progress, :done]}
            conditions.store(:rental_location_code, rental_location_code) if rental_location_code
            
            data = BookingDataSystem::Booking.all(
                :conditions => conditions,
                :order => [:date_from.asc, :time_from.asc]).map do |item|
              product = item.booking_lines.inject('') do |result, b_l|
                result << b_l.item_id
                b_l.booking_line_resources.each do |b_l_r|
                  result << ' - '
                  result << (b_l_r.booking_item_reference.nil? ? 'NO ASIGNADO' : b_l_r.booking_item_reference)
                  result << ' '
                end
                result
              end
              extras = item.booking_extras.inject('') do |result, b_e|
                result << b_e.extra_description
                result << "(#{b_e.quantity}) "
                result
              end
              {id: item.id, date_from: item.date_from.to_date.to_datetime, time_from: item.time_from, pickup_place: item.pickup_place, product: product,
               status: item.status, customer: "#{item.customer_name} #{item.customer_surname}", customer_phone: item.customer_phone, customer_mobile_phone: item.customer_mobile_phone,
               customer_email: item.customer_email, flight: "#{item.flight_airport_origin} #{item.flight_company} #{item.flight_number} #{item.flight_time}",
               total_pending: item.total_pending, extras: extras, notes: item.notes, days: item.days, rental_location_code: item.rental_location_code}
            end
            
            # Include journal
            
            if include_journal
              journal_calendar = ::Yito::Model::Calendar::Calendar.first(name: 'booking_journal')
              event_type = ::Yito::Model::Calendar::EventType.first(name: 'booking_pickup')
              journal_events = ::Yito::Model::Calendar::Event.all(
                  :fields => [:id, :from, :description],
                  :conditions => {:from.gte => from, :from.lt => to+1, event_type_id: event_type.id,
                                  :calendar_id => journal_calendar.id},
                  :order => [:from.asc]).map.each do |journal_event|
                {id: '.', date_from: journal_event.from.to_date.to_datetime,
                 time_from: journal_event.from.strftime('%H:%M'), pickup_place: '', product: journal_event.description,
                 status: '', customer: '', customer_phone: '', customer_mobile_phone: '',
                 customer_email: '', flight: '', total_pending: 0, extras: '', notes: '', days: 0}
              end
              data.concat(journal_events)
            end

            data.sort! do |x, y|
              comp = x[:date_from] <=> y[:date_from]
              if comp.zero?
                begin
                  Time.parse(x[:time_from]) <=> Time.parse(y[:time_from])
                rescue
                  comp
                end
              else
                comp
              end
            end

            return data

          end

          #
          # Return list (including journal)
          #
          def return_list(from, to, rental_location_code=nil, include_journal=false)

            # Get reservations
            conditions = {:date_to.gte => from,
                          :date_to.lte => to,
                          :status => [:confirmed, :in_progress, :done]}
            conditions.store(:rental_location_code, rental_location_code) if rental_location_code


            data = BookingDataSystem::Booking.all(
                :conditions => conditions,
                :order => [:date_to.asc, :time_to.asc]).map do |item|
              product = item.booking_lines.inject('') do |result, b_l|
                result << b_l.item_id
                b_l.booking_line_resources.each do |b_l_r|
                  result << ' - '
                  result << (b_l_r.booking_item_reference.nil? ? 'NO ASIGNADO' : b_l_r.booking_item_reference)
                  result << ' '
                end
                result
              end
              extras = item.booking_extras.inject('') do |result, b_e|
                result << b_e.extra_description
                result << "(#{b_e.quantity}) "
                result
              end
              {id: item.id, date_to: item.date_to.to_date.to_datetime, time_to: item.time_to, return_place: item.return_place, product: product,
               status: item.status, customer: "#{item.customer_name} #{item.customer_surname}", customer_phone: item.customer_phone, customer_mobile_phone: item.customer_mobile_phone,
               customer_email: item.customer_email, flight: "#{item.flight_airport_origin} #{item.flight_company} #{item.flight_number} #{item.flight_time}",
               departure_flight: "#{item.flight_airport_destination} #{item.flight_company_departure} #{item.flight_number_departure} #{item.flight_time_departure}",
               total_pending: item.total_pending, extras: extras, notes: item.notes, days: item.days}
            end

            # Include Journal

            if include_journal
              journal_calendar = ::Yito::Model::Calendar::Calendar.first(name: 'booking_journal')
              event_type = ::Yito::Model::Calendar::EventType.first(name: 'booking_return')
              journal_events = ::Yito::Model::Calendar::Event.all(
                  :fields => [:id, :from, :description],
                  :conditions => {:from.gte => from, :from.lt => to+1, event_type_id: event_type.id,
                                  :calendar_id => journal_calendar.id},
                  :order => [:to.asc]).map do |journal_event|
                {id: '.', date_to: journal_event.from.to_date.to_datetime, time_to: journal_event.from.strftime('%H:%M'),
                 return_place: '', product: journal_event.description, status: '', customer: '', customer_phone: '', customer_mobile_phone: '',
                 customer_email: '', flight: '', total_pending: 0, extras: '', notes: '', days: 0}
              end
              data.concat(journal_events)
            end

            data.sort! do |x, y|
              comp = x[:date_to] <=> y[:date_to]
              if comp.zero?
                begin
                  Time.parse(x[:time_to]) <=> Time.parse(y[:time_to])
                rescue
                  comp
                end
              else
                comp
              end
            end

            return data

          end

          # Detailed picked up products
          #
          def detailed_picked_up_products(date_from, date_to)

            repository.adapter.select(query_detailed_picked_up_products, date_from, date_to).sort do |x,y|
              comp = x.date_from <=> y.date_from
              comp.zero? ? Time.parse(x.time_from) <=> Time.parse(y.time_from) : comp
            end
            
          end

          # Finance finished reservations
          #
          def finances_finished_reservations(date_from, date_to)

            repository.adapter.select(query_finances_finished_reservations, date_from, date_to).sort do |x,y|
              comp = x.date_to <=> y.date_to
              comp.zero? ? Time.parse(x.time_to) <=> Time.parse(y.time_to) : comp
            end
            
          end

          #
          # Get the resources that are returned and delivered the same day
          #
          def returned_delivered_same_day_resources
            today = Date.today
            data = repository.adapter.select(query_overbooking_conflicts, today, today, today, today).map do |item|
              value = {}
              if item.date_from_1 > item.date_from_2
                value['booking_id_1'] = item.booking_id_2
                value['date_from_1'] = item.date_from_2
                value['time_from_1'] = item.time_from_2
                value['date_to_1'] = item.date_to_2
                value['time_to_1'] = item.time_to_2
                value['resource_id_1'] = item.resource_id_2
                value['booking_item_reference_1'] = item.booking_item_reference_2
                value['booking_id_2'] = item.booking_id_1
                value['date_from_2'] = item.date_from_1
                value['time_from_2'] = item.time_from_1
                value['date_to_2'] = item.date_to_1
                value['time_to_2'] = item.time_to_1
                value['resource_id_2'] = item.resource_id_1
                value['booking_item_reference_2'] = item.booking_item_reference_1
                OpenStruct.new(value)
              else
                item
              end
            end
          end

          #
          # Check overbooking conflicts
          #
          def overbooking_conflicts

            returned_delivered_same_day_resources.select do |item|
              begin
                t1 = DateTime.strptime(item.time_to_1,"%H:%M")
                t2 = DateTime.strptime(item.time_from_2,"%H:%M")
                diff = ((t2 - t1).to_f * 24).to_i
                diff < 2
              rescue
                true
              end
            end

          end

          private
    
          def select_pending_of_assignation(b)
            # We can assign reservations starting or ending up to 7 days before today
            date = (Date.today - 7).strftime("%Y-%m-%d")
            sql = <<-QUERY
                select #{b.*} 
                FROM #{b} 
                join bookds_bookings_lines bl on bl.booking_id = #{b.id} 
                join bookds_bookings_lines_resources blr on blr.booking_line_id = bl.id
                where #{b.status} NOT IN (1,5) and blr.booking_item_reference IS NULL and (#{b.date_from} >= '#{date}' or #{b.date_to} >= '#{date}')
            QUERY
          end

          def select_resource_reservations(b) 
             sql = <<-QUERY
               select #{b.*}
               FROM #{b}
                join bookds_bookings_lines bl on bl.booking_id = #{b.id} 
                join bookds_bookings_lines_resources blr on blr.booking_line_id = bl.id
                where #{b.status} NOT IN (1,5) and
                      blr.booking_item_stock_plate = ? and 
                     ((#{b.date_from} <= ? and #{b.date_to} >= ?) or 
                      (#{b.date_from} <= ? and #{b.date_to} >= ?) or 
                      (#{b.date_from} = ? and #{b.date_to} = ?) or
                      (#{b.date_from} >= ? and #{b.date_to} <= ?))                      
             QUERY
          end

          def hour_array(time_from, time_to, step, steps, last_time)
            first = time_from
            last = time_to == last_time ? last_time : time_to.split(':').last == '00' ? "#{time_to.split(':').first.to_i-1}:30" : "#{time_to.split(':').first}:00"

            duration = ((Time.parse(time_to)-Time.parse(time_from))/3600)
            duration += step if time_to == last_time

            hour = first.split(':').first.to_i
            index = steps.index(first.split(':').last) + 1
            index = 0 if index > steps.size-1

            result = [first]

            (1..duration*(1/step).to_i-1).each do |item|    
              hour = hour + 1 if steps[index] == '00'
              result << "#{hour.to_s.rjust(2,'00')}:#{steps[index]}"
              index = index + 1
              index = 0 if index > steps.size-1
            end
            return result
          end
          
          #
          # Check the resources that are assigned for day
          #
          def resources_occupation_query(from, to, options=nil)

            extra_condition = ''
            extra_pr_condition = ''

            unless options.nil?
              if options.has_key?(:mode)
                if options[:mode].to_sym == :stock and options.has_key?(:reference)
                  extra_condition = "and r.booking_item_reference = '#{options[:reference]}' "
                  extra_pr_condition = "and prl.booking_item_reference = '#{options[:reference]}' "
                elsif options[:mode].to_sym == :product and options.has_key(:product)
                  extra_condition = "and item_id = '#{options[:product]}' "
                  extra_condition = "and prl.booking_item_category = '#{options[:product]}' "
                end
              end
            end

            date_diff_reservations = query_strategy.date_diff('b.date_from', 'b.date_to', 'days')
            date_diff_prereservations = query_strategy.date_diff('pr.date_from', 'pr.date_to', 'days')

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
                     b.notes as notes
                FROM bookds_bookings b
                JOIN bookds_bookings_lines l on l.booking_id = b.id
                JOIN bookds_bookings_lines_resources r on r.booking_line_id = l.id
                WHERE ((b.date_from <= '#{from}' and b.date_to >= '#{from}') or 
                   (b.date_from <= '#{to}' and b.date_to >= '#{to}') or 
                   (b.date_from = '#{from}' and b.date_to = '#{to}') or
                   (b.date_from >= '#{from}' and b.date_to <= '#{to}')) and
                    b.status NOT IN (1,5) #{extra_condition}
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
                     pr.notes as notes              
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

          #
          # Check the extras that are assigned for day
          #
          def extras_occupation_query(from, to, options=nil)

            extra_condition = ''

            unless options.nil?
              if options.has_key?(:mode)
                if options[:mode] == 'extra' and options.has_key(:extra)
                  extra_condition = "and e.extra_id = #{options[:product]}"
                end
              end
            end

            date_diff_reservations = query_strategy.date_diff('b.date_from', 'b.date_to', 'days')

            query = <<-QUERY
              SELECT * 
              FROM (
                SELECT e.extra_id,
                       b.id,
                       b.date_from, b.time_from,
                       b.date_to, b.time_to,
                       #{date_diff_reservations},
                       CONCAT(b.customer_name, ' ', b.customer_surname) as title,
                       b.planning_color
                FROM bookds_bookings b
                JOIN bookds_bookings_extras e on e.booking_id = b.id
                WHERE ((b.date_from <= '#{from}' and b.date_to >= '#{from}') or 
                   (b.date_from <= '#{to}' and b.date_to >= '#{to}') or 
                   (b.date_from = '#{from}' and b.date_to = '#{to}') or
                   (b.date_from >= '#{from}' and b.date_to <= '#{to}')) and
                    b.status NOT IN (1,5) #{extra_condition}
              ) AS D                    
              ORDER BY extra_id, date_from
            QUERY

          end  

          #
          # Get the occupation query SQL
          #
          def occupation_query(from, to)

              query = <<-QUERY
                SELECT coalesce(lr.booking_item_category, l.item_id) as item_id, 
                       b.id, 
                       b.date_from as date_from,
                       b.date_to as date_to,
                       b.days as days,
                       lr.booking_item_reference, 
                       1 as quantity 
                FROM bookds_bookings_lines as l
                JOIN bookds_bookings as b on b.id = l.booking_id
                JOIN bookds_bookings_lines_resources as lr on lr.booking_line_id = l.id
                WHERE ((b.date_from <= '#{from}' and b.date_to >= '#{from}') or 
                   (b.date_from <= '#{to}' and b.date_to >= '#{to}') or 
                   (b.date_from = '#{from}' and b.date_to = '#{to}') or
                   (b.date_from >= '#{from}' and b.date_to <= '#{to}')) and
                   b.status NOT IN (1,5)
                UNION
                SELECT prl.booking_item_category as item_id,
                       pr.id,
                       pr.date_from as date_from,
                       pr.date_to as date_to,
                       pr.days as days,
                       prl.booking_item_reference,
                       1 as quantity
                FROM bookds_prereservations pr
                JOIN bookds_prereservation_lines prl on prl.prereservation_id = pr.id
                WHERE ((pr.date_from <= '#{from}' and pr.date_to >= '#{from}') or 
                   (pr.date_from <= '#{to}' and pr.date_to >= '#{to}') or 
                   (pr.date_from = '#{from}' and pr.date_to = '#{to}') or
                   (pr.date_from >= '#{from}' and pr.date_to <= '#{to}'))
                ORDER BY item_id, date_from              
              QUERY

          end

          #
          # Retrieve the pickuped up products on a range of dates
          #
          def query_detailed_picked_up_products

            query = <<-QUERY
              select b.id, 
                     b.date_from, b.time_from, b.date_to, b.time_to,
                     booking_item_stock_model, booking_item_stock_plate, booking_item_characteristic_1, booking_item_characteristic_2, booking_item_characteristic_3, booking_item_characteristic_4,
                     b.driver_name, b.driver_surname, b.driver_document_id, b.driver_date_of_birth, b.driver_driving_license_number,
                     a.street, a.number, a.complement, a.city, a.state, a.country, a.zip
              from bookds_bookings b
              join bookds_bookings_lines bl on bl.booking_id = b.id
              join bookds_bookings_lines_resources blr on blr.booking_line_id = bl.id
              join locds_address a on a.id = b.driver_address_id
              where b.date_from >= ? and b.date_from <= ? and b.status NOT IN (1,5)
              order by b.id;
            QUERY

          end

          #
          # Retrive the returned products on a range of dates 
          #
          def query_finances_finished_reservations

            query = <<-QUERY
              select b.id, booking_item_stock_model, booking_item_stock_plate, b.driver_name, b.driver_surname,
                     b.date_from, b.time_from, b.date_to, b.time_to, b.total_cost
              from bookds_bookings b
              join bookds_bookings_lines bl on bl.booking_id = b.id
              join bookds_bookings_lines_resources blr on blr.booking_line_id = bl.id
              where b.date_to >= ? and b.date_to <= ? and b.status NOT IN (1,5)
              order by b.id;
            QUERY

          end

          #
          # Retrieve information about the
          #
          def query_overbooking_conflicts

            query = <<-QUERY
              select b1.id as booking_id_1, b1.date_from as date_from_1, b1.time_from as time_from_1, b1.date_to as date_to_1, b1.time_to as time_to_1, r1.id as resource_id_1, r1.booking_item_reference as booking_item_reference_1,
                     b2.id as booking_id_2, b2.date_from as date_from_2, b2.time_from as time_from_2, b2.date_to as date_to_2, b2.time_to as time_to_2, r2.id as resource_id_2, r2.booking_item_reference as booking_item_reference_2
              from (
                  select distinct least(r1.resource_id, r2.resource_id) as resource_id1, greatest(r1.resource_id, r2.resource_id) as resource_id2
                  from (
                    select b.id as booking_id, b.date_from, b.time_from, b.date_to, b.time_to, r.id as resource_id, r.booking_item_reference
                    from bookds_bookings_lines_resources r
                    join bookds_bookings_lines l on l.id = r.booking_line_id
                    join bookds_bookings b on b.id = l.booking_id
                    where (b.date_from >= ? or b.date_to >= ?) and r.booking_item_reference is not null and b.status not in (1,5)
                  ) as r1
                  inner join (
                    select b.id as booking_id, b.date_from, b.time_from, b.date_to, b.time_to, r.id as resource_id, r.booking_item_reference
                    from bookds_bookings_lines_resources r
                    join bookds_bookings_lines l on l.id = r.booking_line_id
                    join bookds_bookings b on b.id = l.booking_id
                    where (b.date_from >= ? or b.date_to >= ?) and r.booking_item_reference is not null and b.status not in (1,5)
                  ) as r2 on r2.booking_item_reference = r1.booking_item_reference and r2.resource_id != r1.resource_id
                  group by r1.resource_id, r2.resource_id    
                ) as x
                join bookds_bookings_lines_resources r1 on r1.id = resource_id1
                join bookds_bookings_lines l1 on l1.id = r1.booking_line_id
                join bookds_bookings b1 on b1.id = l1.booking_id
                join bookds_bookings_lines_resources r2 on r2.id = resource_id2
                join bookds_bookings_lines l2 on l2.id = r2.booking_line_id
                join bookds_bookings b2 on b2.id = l2.booking_id
                join bookds_items on r1.booking_item_reference = bookds_items.reference and bookds_items.assignable 
                where ((b1.date_from <= b2.date_from and b1.date_to >= b2.date_from) or (b1.date_from >= b2.date_from and b1.date_to <= b2.date_to) or (b1.date_from >= b2.date_from and b1.date_from <= b2.date_to))
                order by least(b1.date_from,b2.date_from)
            QUERY

          end


          def query_strategy

            # Removed for multi-tenant solution
            #@query_strategy ||= 
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