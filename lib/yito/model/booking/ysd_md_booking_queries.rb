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
                               Conditions::Comparison.new(:customer_surname, '$like', "%#{search_text}%"),
                               Conditions::Comparison.new(:customer_email, '$eq', search_text),
                               Conditions::Comparison.new(:customer_phone, '$eq', search_text),
                               Conditions::Comparison.new(:customer_mobile_phone, '$eq', search_text)])
            
              total = conditions.build_datamapper(BookingDataSystem::Booking).all.count 
              data = conditions.build_datamapper(BookingDataSystem::Booking).all(offset_order_query) 
              [total, data]
             end
          end

          def incoming_money_summary(year)
            query_strategy.incoming_money_summary(year)
          end

          def reservations_received(year)
            query_strategy.reservations_received(year)
          end

          def reservations_confirmed(year)
            query_strategy.reservations_confirmed(year)
          end

          def count_received_reservations(year)
            query_strategy.count_received_reservations(year)
          end

          def count_pending_confirmation_reservations(year)
            query_strategy.count_pending_confirmation_reservations(year)
          end

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
          # Get the stock total cost
          #
          def stock_cost_total
            query_strategy.stock_cost_total.first || 0
          end

          #
          # Products billing summary detailed by stock item
          #
          def products_billing_summary_by_stock(year)
            # Build the result holder
            total_cost = 0
            stock_items = ::Yito::Model::Booking::BookingItem.all(conditions: {active: true}, fields: [:reference, :cost], order: [:category_code, :reference])
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
            result
          end

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

          def reservations_by_status(year)
 
            data = query_strategy.reservations_by_status(year)


            result = data.inject({}) do |result, value|
               status = case value.status
                          when 1
                             'pending-confirmation'
                          when 2 
                             'confirmed'
                          when 3 
                             'in-progress'
                          when 4 
                             'done'
                          when 5 
                             'canceled'
                        end

               result.store(status, {value: value.count,
                                     color: "#%06x" % (rand * 0xffffff),
                                     highlight: "#%06x" % (rand * 0xffffff),
                                     label: status})
               result
            end

            result

          end

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
          
          #
          # Check the occupation of renting items for a period
          #
          def occupation(from, to)
                      
            result = []

            data, detail = resources_occupation(from, to)
            detail.each do |key, value|
              result << OpenStruct.new(item_id: key, stock: value[:stock], busy: value[:occupation])
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
                      pr.booking_item_reference,
                      pr.booking_item_category,
                      'prereservation' as origin
               FROM bookds_prereservations pr
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
                      pr.planning_color,
                      pr.booking_item_reference,
                      pr.booking_item_category,
                      'prereservation' as origin,
                      pr.id as id2,
                      '' as resource_1_name,
                      '' as customer_height,
                      '' as customer_weight,
                      '' as resource_2_name,
                      '' as customer_2_height,
                      '' as customer_2_weight,
                      pr.notes as comments,
                      1 as pax
               FROM bookds_prereservations pr
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
          
          # Get the daily percentage occupation in a period of time 
          #
          def monthly_occupation(month, year, category=nil)
            
            from = Date.civil(year, month, 1)
            to = Date.civil(year, month, -1)
            product_family = ::Yito::Model::Booking::ProductFamily.get(SystemConfiguration::Variable.get_value('booking.item_family'))

            # Get products stocks
            conditions = category.nil? ? {} : {code: category}
            categories = ::Yito::Model::Booking::BookingCategory.all(conditions: conditions.merge({active: true}), fields: [:code, :stock])
            stocks = categories.inject({}) do |result, item|
                       result.store(item.code, item.stock)
                       result
                     end
            
            # Build products occupation
            cat_occupation =  categories.inject({}) do |result, item|
                                days_hash = {}
                                (1..(to.day)).each do |day|
                                  days_hash.store(day, {items:[],occupation:0})
                                end
                                result.store(item.code, days_hash)
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
              calculated_to = calculated_to - 1 unless product_family.cycle_of_24_hours
              (calculated_from..calculated_to).each do |index|
                unless reservation.booking_item_reference.nil?
                  unless cat_occupation[reservation.item_id][index][:items].include?(reservation.booking_item_reference)
                    cat_occupation[reservation.item_id][index][:items] << reservation.booking_item_reference
                  end
                end
                cat_occupation[reservation.item_id][index][:occupation] += reservation.quantity if cat_occupation.has_key?(reservation.item_id)
              end
            end
            
            # Calculate percentage 
            cat_occupation.each do |key, value|  
              value.each do |day, occupation| 
                cat_occupation[key][day][:occupation] = "#{cat_occupation[key][day][:occupation]}/#{stocks[key]}"
              end
            end
   
            cat_occupation

          end
          
          #
          # Get the resources occupation to assign stock
          #
          # Return an array with two elements
          #
          #  - First  : The resources occupation detail for the dates
          #  - Second : The categories availability
          #
          def resources_occupation(date_from, date_to, category=nil)
            
            categories = ::Yito::Model::Booking::BookingCategory.all(conditions: {active: true}, fields: [:code, :stock], order: [:code])            
  
            # 1. Build the result structure
            #    
            items = if category 
                      ::Yito::Model::Booking::BookingItem.all(:conditions => {category_code: 
                        category },
                        :order => [:planning_order, :category_code, :reference])
                    else
                      ::Yito::Model::Booking::BookingItem.all(
                        :order => [:planning_order, :category_code, :reference])
                    end

            result = {}
            items.each do |b_item|
              result.store(b_item.reference, {category: b_item.category_code, 
                                              available: true, 
                                              detail: []})
            end

            # 2. Build the not assigned summary
            #    It holds the confirmed reservations that have not been already assigned
            #    to a resource (stock), so they can be taken into account
            not_assigned_reservations = categories.inject({}) do |result, cat|
              result.store(cat.code, {total: 0, detail: []})
              result
            end

            # 3. Fill with reservations information
            query = resources_occupation_query(date_from, date_to)
            resource_occupations = repository.adapter.select(query)

            resource_occupations.each do |resource_occupation|
              if resource_occupation.booking_item_reference
                if item = result[resource_occupation.booking_item_reference]
                  item[:available] = false
                  item[:detail] << resource_occupation
                end
              else
                if not_assigned_reservations.has_key?(resource_occupation.item_id)
                  not_assigned_reservations[resource_occupation.item_id][:total] += 1
                  not_assigned_reservations[resource_occupation.item_id][:detail] << resource_occupation
                end
              end
            end
            
            # 4. Build category occupation
            stocks = categories.inject({}) do |result, item|
                       result.store(item.code, item.stock || 0)
                       result
                     end
            category_occupation = {}
            
            # 4.1 Fill with stock assignation
            result.each do |key, value|
              if category_occupation.has_key?(value[:category])
                category_occupation[value[:category]][:occupation] += 1 unless value[:available]
                category_occupation[value[:category]][:occupation_assigned] += 1 unless value[:available]
              else
                category_occupation.store(value[:category], {
                        stock: stocks[value[:category]] || 0,
                        occupation: value[:available] ? 0 : 1,
                        occupation_assigned: value[:available] ? 0 : 1,
                        available_stock: [],
                        assignation_pending: []})
              end
              category_occupation[value[:category]][:available_stock] << key if value[:available]
            end
            
            # 4.2 Fill with not assigned
            not_assigned_reservations.each do |key, value|
              if category_occupation.has_key?(key)
                category_occupation[key][:occupation] += value[:detail].size unless value[:detail].empty?
                category_occupation[key][:assignation_pending].concat(value[:detail]) unless value[:detail].empty? 
              end
            end

            return [result, category_occupation]

          end
          
          #
          # Get the planning detail
          #
          def planning(date_from, date_to, options=nil)
            
            # 1. Get the stock 

            references = []
            references_hash = {}

            if !options.nil? and options[:mode] == :stock and options.has_key?(:reference)
              references << options[:reference]
              if item = ::Yito::Model::Booking::BookingItem.get(options[:reference])
                references_hash.store(item.reference, item.category_code)
              else
                references_hash.store(options[:reference], nil)
              end
            elsif !options.nil? and options[:mode] == :product and options.has_key?(:product)
              ::Yito::Model::Booking::BookingItem.all(
                :conditions => {category_code: options[:product]},
                :fields => [:reference, :category_code],
                :order =>  [:planning_order, :category_code, :reference]).each do |item| 
                  references << item.reference
                  references_hash.store(item.reference, item.category_code)
              end
            else
              ::Yito::Model::Booking::BookingItem.all(
                :fields => [:reference, :category_code],
                :order =>  [:planning_order, :category_code, :reference]).each do |item| 
                  references << item.reference
                  references_hash.store(item.reference, item.category_code)
              end
            end
            
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

          private
    
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
                if options[:mode] == 'stock' and options.has_key?(:reference)
                  extra_condition = "and r.booking_item_reference = #{options[:reference]}"
                  extra_pr_condition = "and pr.booking_item_reference = #{options[:reference]}"
                elsif options[:mode] == 'product' and options.has_key(:product)
                  extra_condition = "and item_id = #{options[:product]}"
                  extra_condition = "and pr.booking_item_category = #{options[:product]}"
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
                     b.planning_color
                FROM bookds_bookings b
                JOIN bookds_bookings_lines l on l.booking_id = b.id
                JOIN bookds_bookings_lines_resources r on r.booking_line_id = l.id
                WHERE ((b.date_from <= '#{from}' and b.date_to >= '#{from}') or 
                   (b.date_from <= '#{to}' and b.date_to >= '#{to}') or 
                   (b.date_from = '#{from}' and b.date_to = '#{to}') or
                   (b.date_from >= '#{from}' and b.date_to <= '#{to}')) and
                    b.status NOT IN (1,5) #{extra_condition}
                UNION
                SELECT pr.booking_item_reference,
                     pr.booking_item_category,
                     pr.id,
                     'prereservation' as origin,
                     pr.date_from, pr.time_from,
                     pr.date_to, pr.time_to,
                     #{date_diff_prereservations},
                     pr.title,
                     pr.notes as detail,
                     pr.id as id2,
                     pr.planning_color              
                FROM bookds_prereservations pr
                WHERE ((pr.date_from <= '#{from}' and pr.date_to >= '#{from}') or 
                   (pr.date_from <= '#{to}' and pr.date_to >= '#{to}') or 
                   (pr.date_from = '#{from}' and pr.date_to = '#{to}') or
                   (pr.date_from >= '#{from}' and pr.date_to <= '#{to}')) #{extra_pr_condition}
              ) AS D
              ORDER BY booking_item_reference, date_from
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
                SELECT pr.booking_item_category as item_id,
                       pr.id,
                       pr.date_from as date_from,
                       pr.date_to as date_to,
                       pr.days as days,
                       pr.booking_item_reference,
                       1 as quantity
                FROM bookds_prereservations pr
                WHERE ((pr.date_from <= '#{from}' and pr.date_to >= '#{from}') or 
                   (pr.date_from <= '#{to}' and pr.date_to >= '#{to}') or 
                   (pr.date_from = '#{from}' and pr.date_to = '#{to}') or
                   (pr.date_from >= '#{from}' and pr.date_to <= '#{to}'))
                ORDER BY item_id, date_from              
              QUERY

          end

          def query_strategy
      
            @query_strategy ||= 
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