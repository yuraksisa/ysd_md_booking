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
                         b.customer_name as customer_name, b.customer_surname as customer_surname
                  from payment_charges pc
                  join bookds_booking_charges bc on bc.charge_id = pc.id
                  join bookds_bookings b on bc.booking_id = b.id
                  where pc.status = 4
                  union
                  select pc.id, pc.amount, pc.date, pc.payment_method_id, 
                         'order' as source, oc.order_id as source_id,
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
                      b.customer_name as customer_name, b.customer_surname as customer_surname
                from payment_charges pc
                join bookds_booking_charges bc on bc.charge_id = pc.id
                join bookds_bookings b on bc.booking_id = b.id
                where pc.status = 4 and pc.date >= ? and pc.date <= ?
                order by pc.date
              SQL
            end

            charges = repository.adapter.select(sql, date_from, date_to)

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


          def occupation(from, to)

            query = <<-QUERY
               SELECT l.item_id as item_id, c.stock as stock, count(*) as busy 
               FROM bookds_bookings_lines as l
               JOIN bookds_bookings as b on b.id = l.booking_id
               JOIN bookds_categories as c on c.code = l.item_id
               WHERE ((b.date_from <= '#{from}' and b.date_to >= '#{from}') or 
                   (b.date_from <= '#{to}' and b.date_to >= '#{to}') or 
                   (b.date_from = '#{from}' and b.date_to = '#{to}') or
                   (b.date_from >= '#{from}' and b.date_to <= '#{to}')) and
                   b.status <> 5
               GROUP BY l.item_id, c.stock
            QUERY

            occupation = repository.adapter.select(query)

          end

          # Get the daily percentage occupation in a period of time 
          #
          def monthly_occupation(month, year, category=nil, mode=nil)
            
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
                                  days_hash.store(day, 0)
                                end
                                result.store(item.code, days_hash)
                                result
                              end

            # Query bookings for the period
            
            if mode == 'stock'
              query = <<-QUERY
                SELECT bi.category_code as item_id, 
                       b.id, 
                       b.date_from as date_from,
                       b.date_to as date_to,
                       b.days as days, 
                       1 as quantity 
                FROM bookds_bookings_lines as l
                JOIN bookds_bookings as b on b.id = l.booking_id
                JOIN bookds_bookings_lines_resources as lr on lr.booking_line_id = l.id
                JOIN bookds_items as bi on lr.booking_item_reference = bi.reference
                WHERE ((b.date_from <= '#{from}' and b.date_to >= '#{from}') or 
                   (b.date_from <= '#{to}' and b.date_to >= '#{to}') or 
                   (b.date_from = '#{from}' and b.date_to = '#{to}') or
                   (b.date_from >= '#{from}' and b.date_to <= '#{to}')) and
                   b.status NOT IN (1,5)
              QUERY
            else
              query = <<-QUERY
                SELECT l.item_id as item_id, b.id, b.date_from as date_from,
                      b.date_to as date_to,
                      b.days as days, l.quantity as quantity 
                FROM bookds_bookings_lines as l
                JOIN bookds_bookings as b on b.id = l.booking_id
                WHERE ((b.date_from <= '#{from}' and b.date_to >= '#{from}') or 
                   (b.date_from <= '#{to}' and b.date_to >= '#{to}') or 
                   (b.date_from = '#{from}' and b.date_to = '#{to}') or
                   (b.date_from >= '#{from}' and b.date_to <= '#{to}')) and
                   b.status NOT IN (1,5)
              QUERY
            end

            reservations = repository.adapter.select(query)
            
            # Fill products occupation
            reservations.each do |reservation|
              date_from = reservation.date_from
              date_to = reservation.date_to
              calculated_from = date_from.month < month ? 1 : date_from.day
              calculated_to = date_to.month > month ? to.day : date_to.day 
              calculated_to = calculated_to - 1 unless product_family.cycle_of_24_hours
              (calculated_from..calculated_to).each do |index|
                cat_occupation[reservation.item_id][index] += reservation.quantity if cat_occupation.has_key?(reservation.item_id)
              end
            end
            
            # Calculate percentage 
            cat_occupation.each do |key, value|  
              value.each do |day, occupation| 
                cat_occupation[key][day] = "#{cat_occupation[key][day]}/#{stocks[key]}"
              end
            end    

            cat_occupation

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