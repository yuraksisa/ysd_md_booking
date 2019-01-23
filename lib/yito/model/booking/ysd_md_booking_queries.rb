module Yito
  module Model
    module Booking
      module Queries

        def self.extended(model)
          model.extend ClassMethods
        end

        module ClassMethods

          # --------- Reservation management optimized queries -------------

          def map_optimized_query_results(data)
              data.map! do |item|
                item['status'] = case item['status'].to_i
                                  when 1
                                    'pending_confirmation'
                                  when 2
                                    'confirmed'
                                  when 3
                                    'in_progress'
                                  when 4
                                    'done'
                                  when 5
                                    'cancelled'
                                end          
                item['payment_status'] = case item['payment_status'].to_i
                                          when 1
                                            'none'
                                          when 2
                                            'deposit'
                                          when 3
                                            'total'
                                          when 4
                                            'refunded'      
                                        end
                item                        
             end
          end

          #
          # Search booking by text (customer surname, phone, email)
          #          
          def text_search(search_text, limit, offset)
             query_strategy.text_search(search_text, limit, offset)
          end
          #
          # Search booking by text (customer surname, phone, email)
          #          
          def text_search_multiple(search_text, limit, offset)
             query_strategy.text_search(search_text, limit, offset)
          end


          #
          # Reservation management no conditions
          #
          def reservation_search(limit, offset)
             repository.adapter.select(query_strategy.query_reservation_search(limit, offset))
          end

          #
          # Reservation management pending reservations
          #
          def reservation_search_pending(limit, offset, today)
             extra_condition = "WHERE b.status = 1 and b.date_from >= ?"
             repository.adapter.select(query_strategy.query_reservation_search(limit, offset, extra_condition), today)
          end

          #
          # Reservation management in process reservations
          #
          def reservation_search_in_process(limit, offset, today)
             extra_condition = "WHERE b.status in (2,3) and b.date_from <= ? and date_to >= ?"            
             repository.adapter.select(query_strategy.query_reservation_search(limit, offset, extra_condition), today, today)
          end

          #
          # Reservation management current year confirmed
          #
          def reservation_search_confirmed(limit, offset, first_year_date)
             extra_condition = "WHERE b.status in (2,3,4) and b.creation_date >= ?"
             repository.adapter.select(query_strategy.query_reservation_search(limit, offset, extra_condition), first_year_date)
          end

          #
          # Reservation management current year received
          #
          def reservation_search_received(limit, offset, first_year_date)
             extra_condition = "WHERE b.creation_date >= ?"
             repository.adapter.select(query_reservation_search(limit, offset, extra_condition), first_year_date)            
          end

          def reservation_search_multiple(limit, offset)
            repository.adapter.select(query_strategy.query_reservation_search_multiple(limit, offset))
          end

          def reservation_search_pending_multiple(limit, offset, today)
             extra_condition = " WHERE b.status = 1 and b.date_from >= ? "
             repository.adapter.select(query_strategy.query_reservation_search_multiple(limit, offset, extra_condition), today)
          end

          def reservation_search_in_process_multiple(limit, offset, today)
             extra_condition = "WHERE b.status in (2,3) and b.date_from <= ? and date_to >= ?"            
             repository.adapter.select(query_strategy.query_reservation_search_multiple(limit, offset, extra_condition), today, today)
          end    

          def reservation_search_confirmed_multiple(limit, offset, first_year_date)
             extra_condition = "WHERE b.status in (2,3,4) and b.creation_date >= ?"
             repository.adapter.select(query_strategy.query_reservation_search_multiple(limit, offset, extra_condition), first_year_date)
          end                

          def reservation_search_received_multiple(limit, offset, first_year_date)
             extra_condition = "WHERE b.creation_date >= ?"
             repository.adapter.select(query_strategy.query_reservation_search_multiple(limit, offset, extra_condition), first_year_date)
          end  

          def query_reservation_search(limit, offset, extra_condition='')
              if DataMapper::Adapters.const_defined?(:PostgresAdapter) and repository.adapter.is_a?DataMapper::Adapters::PostgresAdapter
                 sql = <<-SQL
                    SELECT b.id as id, customer_name, customer_surname, date_from, date_to, CAST(status as INTEGER) as status, 
                           CAST(payment_status as INTEGER) as payment_status, creation_date, created_by_manager, rental_location_code,
                           (select array_to_string(array_agg(bl.item_id), ' ') from bookds_bookings_lines bl where bl.booking_id = b.id) as item_id
                    FROM bookds_bookings b
                    #{extra_condition}
                    ORDER BY b.id desc
                    LIMIT #{limit} OFFSET #{offset}
                 SQL
              else
                sql = <<-SQL
                  SELECT b.id, customer_name, customer_surname, date_from, date_to, CAST(status as UNSIGNED) as status, 
                         CAST(payment_status as UNSIGNED) as payment_status, creation_date, created_by_manager, rental_location_code,
                         GROUP_CONCAT(CONCAT(bl.item_id)) as item_id
                  FROM bookds_bookings b
                  JOIN bookds_bookings_lines bl on bl.booking_id = b.id
                  #{extra_condition}
                  GROUP BY bl.booking_id
                  ORDER BY b.id desc
                  LIMIT #{limit} OFFSET #{offset}
                SQL
              end
          end

          def query_reservation_search_multiple(limit, offset, extra_condition='')
            if DataMapper::Adapters.const_defined?(:PostgresAdapter) and repository.adapter.is_a?DataMapper::Adapters::PostgresAdapter
                sql = <<-SQL
                    SELECT b.id, customer_name, customer_surname, date_from, date_to, CAST(status as INTEGER) as status, 
                           CAST(payment_status as INTEGER) as payment_status, creation_date, created_by_manager, rental_location_code,
                           (select array_to_string(array_agg(concat(bl.item_id, '(', bl.quantity,' u.)')), ' ') from bookds_bookings_lines bl where bl.booking_id = b.id) as item_id
                    FROM bookds_bookings b
                    JOIN bookds_bookings_lines bl on bl.booking_id = b.id
                    #{extra_condition}
                    GROUP BY bl.booking_id
                    ORDER BY b.id desc
                    LIMIT #{limit} OFFSET #{offset}
                SQL

            else
                sql = <<-SQL
                    SELECT b.id, customer_name, customer_surname, date_from, date_to, CAST(status as UNSIGNED) as status, 
                           CAST(payment_status as UNSIGNED) as payment_status, creation_date, created_by_manager, rental_location_code,
                           GROUP_CONCAT(CONCAT(bl.item_id, ' (', bl.quantity,' u.)') SEPARATOR ' ') as item_id
                    FROM bookds_bookings b
                    JOIN bookds_bookings_lines bl on bl.booking_id = b.id
                    #{extra_condition}
                    GROUP BY bl.booking_id
                    ORDER BY b.id desc
                    LIMIT #{limit} OFFSET #{offset}
                SQL
            end              
          end
           
          # --------- Search customers from reservation -------------

          #
          # Reservation customers
          # ---------------------------------------------------------------------------------------------------------
          #
          def customers(from=nil, to=nil, sales_channel_code=nil)
            
            conditions = "(status not in (1,5))"
            query_parameters = []
            
            if !from.nil? and !to.nil?
              conditions << "and (bookds_bookings.date_from >= ? and bookds_bookings.date_from <= ?)"
              query_parameters << from
              query_parameters << to
            end 

            if sales_channel_code.nil? or sales_channel_code.empty?
              conditions << "and (sales_channel_code IS NULL or sales_channel_code = '')" 
            elsif sales_channel_code != 'all'
              conditions << "and (sales_channel_code = ?)" 
              query_parameters << sales_channel_code 
            end

            conditions.prepend("where ") unless conditions.empty?

            query = <<-QUERY
              select trim(upper(customer_surname)) as customer_surname, 
                     trim(upper(customer_name)) as customer_name, 
                     lower(customer_email) as customer_email, 
                     customer_phone,
                     sales_channel_code,
                     locds_address.street as street,
                     locds_address.number as number,
                     locds_address.complement as complement,
                     locds_address.city as city,
                     locds_address.state as state,
                     locds_address.zip as zip,
                     locds_address.country as country       
              FROM bookds_bookings 
              left join locds_address on locds_address.id = bookds_bookings.driver_address_id
              #{conditions}
              group by trim(upper(customer_surname)), trim(upper(customer_name)), lower(customer_email), customer_phone,
                    sales_channel_code, street, number, complement, city, state, zip, country
              order by customer_surname, customer_name
            QUERY

            #p "query: #{query} query_paramaters: #{query_parameters.inspect}"  

            if query_parameters.empty?
              repository.adapter.select(query)
            else
              repository.adapter.select(query, *query_parameters)
            end

          end  

          #
          # Reservation customers
          # ---------------------------------------------------------------------------------------------------------
          #
          # Search customers (and groups by surname, name, phone, email) from bookings
          #
          def customer_search(search_text, options={})
            [query_strategy.count_customer_search(search_text),
             query_strategy.customer_search(search_text, options)]
          end

          #
          # First booking customer
          # ---------------------------------------------------------------------------------------------------------
          #
          # Get the first customer booking
          # 
          def first_customer_booking(params)
            query_strategy.first_customer_booking(params)
          end

          # ----------------------------- Reservation listing -------------------------------------------------------

          #
          # Pending of assignation
          # ---------------------------------------------------------------------------------------------------------
          #
          # Get the reservations pending of assignation
          #
          # Note: We can assign reservations starting or ending up to 7 days before today
          #
          def pending_of_assignation
            p "LOADING-PENDING-OF-ASSIGNATION"
            BookingDataSystem::Booking.by_sql{ |b| [select_pending_of_assignation(b)] }.all(order: :date_from) 

          end

          def pending_of_assignation_count
            repository.adapter.select(select_pending_of_assignation_count).first.to_i
          end

          #
          # Resource reservation by stock plate
          # ---------------------------------------------------------------------------------------------------------
          #
          # Get the detail of the reservations that involve a resource
          #
          def resource_reservations(date_from, date_to, stock_plate_or_reference)

             BookingDataSystem::Booking.by_sql { |b| 
               [select_resource_reservations(b), stock_plate_or_reference, stock_plate_or_reference,
                 date_from, date_from, 
                 date_to, date_to,
                 date_from, date_to,
                 date_from, date_to ] }.all(order: :date_from) 

          end

          #
          # Resource reservations by reference
          # ---------------------------------------------------------------------------------------------------------
          #
          def resource_reservations_by_item_reference(date_from, date_to, item_reference)

            BookingDataSystem::Booking.by_sql { |b|
              [select_resource_reservations_by_item_reference(b), stock_plate,
               date_from, date_from,
               date_to, date_to,
               date_from, date_to,
               date_from, date_to ] }.all(order: :date_from)

          end

          #
          # Started reservations
          # ---------------------------------------------------------------------------------------------------------
          #
          # Started reservations in a date interval
          #
          #
          def finances_started_reservations(date_from, date_to)

            repository.adapter.select(query_finances_started_reservations, date_from, date_to).sort do |x,y|
              comp = x.date_from <=> y.date_from
              comp.zero? ? Time.parse(x.time_from) <=> Time.parse(y.time_from) : comp
            end

          end

          #
          # Finished reservations
          # ---------------------------------------------------------------------------------------------------------
          #
          # Finished reservations in a date interval
          #
          #
          def finances_finished_reservations(date_from, date_to)

            repository.adapter.select(query_finances_finished_reservations, date_from, date_to).sort do |x,y|
              comp = x.date_to <=> y.date_to
              comp.zero? ? Time.parse(x.time_to) <=> Time.parse(y.time_to) : comp
            end

          end
          
          # -------------------------- Pickup / Delivery ------------------------------------------------------------
          
          # 
          # Pickup count
          #
          def pickup_count(from, to, rental_location_code=nil, include_journal=false)

            conditions = {:date_from.gte => from,
                          :date_from.lte => to,
                          :status => [:confirmed, :in_progress, :done]}
            conditions.store(:rental_location_code, rental_location_code) if rental_location_code

            count = BookingDataSystem::Booking.count(conditions: conditions)

            if include_journal
              sql = <<-SQL
                select count(*)
                from cal_event c_e
                join cal_event_type c_e_t on c_e_t.id = c_e.event_type_id 
                join cal_calendar c on c.id = c_e.calendar_id
                where c_e.from >= ? and c_e.from < ? and c_e_t.name = ? and c.name = ?
              SQL
              count +=  repository.adapter.select(sql, from, to+1, 'booking_journal', 'booking_pickup').first.to_i
            end  

            return count

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
          # Pickup count
          #
          def return_count(from, to, rental_location_code=nil, include_journal=false)

            conditions = {:date_to.gte => from,
                          :date_to.lte => to,
                          :status => [:confirmed, :in_progress, :done]}
            conditions.store(:rental_location_code, rental_location_code) if rental_location_code

            count = BookingDataSystem::Booking.count(conditions: conditions)

            if include_journal
              sql = <<-SQL
                select count(*)
                from cal_event c_e
                join cal_event_type c_e_t on c_e_t.id = c_e.event_type_id 
                join cal_calendar c on c.id = c_e.calendar_id
                where c_e.to >= ? and c_e.to < ? and c_e_t.name = ? and c.name = ?
              SQL
              count +=  repository.adapter.select(sql, from, to+1, 'booking_journal', 'booking_pickup').first.to_i
            end  

            return count

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

          # -------------------------- Charges --------------------------------------------------------------

          #
          # Charges
          # -------------------------------------------------------------------------------------------------
          #
          # Get the charges between two dates
          #
          def charges(date_from, date_to)

            sql = <<-SQL
              select * 
              from (
                select pc.id, pc.amount, pc.date, pc.payment_method_id, 
                       'booking' as source, 
                       bc.booking_id as source_id,
                       'booking' as source_link,
                       b.customer_name as customer_name, b.customer_surname as customer_surname,
                       b.driver_document_id as customer_document_id,
                       case when pc.payment_type = 1 then 'charge' else 'payment' end as payment_type
                from payment_charges pc
                join bookds_booking_charges bc on bc.charge_id = pc.id
                join bookds_bookings b on bc.booking_id = b.id
                where pc.status = 4
                union
                select pc.id, pc.amount, pc.date, pc.payment_method_id, 
                       'order' as source, 
                       oc.order_id as source_id,
                       'order' as source_link,
                       o.customer_name as customer_name, o.customer_surname as customer_surname,
                       o.customer_document_id as customer_document_id,
                       case when pc.payment_type = 1 then 'charge' else 'payment' end as payment_type
                from payment_charges pc
                join orderds_order_charges oc on oc.charge_id = pc.id
                join orderds_orders o on oc.order_id = o.id
                where pc.status = 4
                union
                select pc.id, pc.amount, pc.date, pc.payment_method_id, 
                       case when pc.payment_type = 1 then 'customer_invoice' else 'customer_payment' end as source, 
                       cic.customer_invoice_id as source_id,
                       case when pc.payment_type = 1 then 'customer_invoice' else 'customer_payment' end as source_link,
                       ci.customer_full_name as customer_name, '' as customer_surname,
                       ci.customer_document_id as customer_document_id,
                       case when pc.payment_type = 1 then 'charge' else 'payment' end as payment_type
                from payment_charges pc
                join invoiceds_customer_invoice_charges cic on cic.charge_id = pc.id
                join invoiceds_customer_invoices ci on cic.customer_invoice_id = ci.id
                where pc.status = 4                  
              ) as data_charges
              where data_charges.date >= ? and data_charges.date <= ?
              order by data_charges.date
            SQL

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
              elsif charge.source_link == 'customer_invoice'
                  charge.source_link = "<a href=\"/admin/invoices/customer-invoices/#{charge.source_id}\">#{YsdPluginInvoices.r18n.t.customer_invoice_model.charge_description(charge.source_id)}</a>"
                  charge.source = YsdPluginInvoices.r18n.t.customer_invoice_model.charge_description(charge.source_id)   
              elsif charge.source_link == 'customer_payment' 
                  charge.source_link = "<a href=\"/admin/invoices/customer-invoices/#{charge.source_id}\">#{YsdPluginInvoices.r18n.t.customer_invoice_model.payment_description(charge.source_id)}</a>"
                  charge.source = YsdPluginInvoices.r18n.t.customer_invoice_model.payment_description(charge.source_id)                         
              end
            end

            return charges

          end

          # --------------------------- Invoicing basic ------------------------------------------------------------

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

          # --------------------------- Cost analysis --------------------------------------------------------------
          #
          # NOTE: Those methods are part of the analysis extension add-on
          #

          #
          # Historic stock
          # -------------------------------------------------------------------------------------------------------
          #
          # Get the stock that where used in the reservations in a year
          #
          def historic_stock(year)

            data = query_strategy.historic_stock(year)

          end

          #
          # Inventory year billing summary
          # -------------------------------------------------------------------------------------------------------
          #
          # Billing summary grouped by month an resource
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


          private

          def select_pending_of_assignation_count
            date = (Date.today - 7).strftime("%Y-%m-%d")
            sql = <<-QUERY
                select count(*)
                FROM bookds_bookings b
                join bookds_bookings_lines bl on bl.booking_id = b.id 
                join bookds_bookings_lines_resources blr on blr.booking_line_id = bl.id
                where b.status NOT IN (1,5) and blr.booking_item_reference IS NULL and (b.date_from >= '#{date}' or b.date_to >= '#{date}')
            QUERY

          end
    
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
                      (blr.booking_item_stock_plate = ? or blr.booking_item_reference = ?) and 
                     ((#{b.date_from} <= ? and #{b.date_to} >= ?) or 
                      (#{b.date_from} <= ? and #{b.date_to} >= ?) or 
                      (#{b.date_from} = ? and #{b.date_to} = ?) or
                      (#{b.date_from} >= ? and #{b.date_to} <= ?))                      
             QUERY
          end

          def select_resource_reservations_by_item_reference(b)
            sql = <<-QUERY
               select #{b.*}
               FROM #{b}
                join bookds_bookings_lines bl on bl.booking_id = #{b.id} 
                join bookds_bookings_lines_resources blr on blr.booking_line_id = bl.id
                where #{b.status} NOT IN (1,5) and
                      blr.booking_item_reference = ? and 
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
          # Retrive the started reservations between on a range of dates 
          #
          def query_finances_started_reservations

            query = <<-QUERY
              select b.id, booking_item_stock_model, booking_item_stock_plate, b.driver_name, b.driver_surname,
                     b.date_from, b.time_from, b.date_to, b.time_to, b.notes, b.total_cost
              from bookds_bookings b
              join bookds_bookings_lines bl on bl.booking_id = b.id
              join bookds_bookings_lines_resources blr on blr.booking_line_id = bl.id
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
                     b.date_from, b.time_from, b.date_to, b.time_to, b.notes, b.total_cost
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