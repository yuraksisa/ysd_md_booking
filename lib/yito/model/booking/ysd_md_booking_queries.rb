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

            result = {}
            (0..29).reverse_each do |item| 
              result.store(item, 0)
            end

            data = query_strategy.last_30_days_reservations
            data.each do |item|
               result.store(item.period, item.occurrences) if result.has_key?(item.period)
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
          def monthly_occupation(month, year, category=nil)
            
            from = Date.civil(year, month, 1)
            to = Date.civil(year, month, -1)
            product_family = ::Yito::Model::Booking::ProductFamily.get(SystemConfiguration::Variable.get_value('booking.item_family'))

            # Get products stocks
            conditions = category.nil? ? {} : {code: category}
            categories = ::Yito::Model::Booking::BookingCategory.all(conditions: conditions, fields: [:code, :stock])
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
            query = <<-QUERY
               SELECT l.item_id as item_id, b.id, b.date_from as date_from,
                      b.days as days, l.quantity as quantity 
               FROM bookds_bookings_lines as l
               JOIN bookds_bookings as b on b.id = l.booking_id
               WHERE ((b.date_from <= '#{from}' and b.date_to >= '#{from}') or 
                   (b.date_from <= '#{to}' and b.date_to >= '#{to}') or 
                   (b.date_from = '#{from}' and b.date_to = '#{to}') or
                   (b.date_from >= '#{from}' and b.date_to <= '#{to}')) and
                   b.status <> 5
            QUERY
            reservations = repository.adapter.select(query)
            
            # Fill products occupation
            reservations.each do |reservation|
              date_from = reservation.date_from
              calculated_to = date_from.day+reservation.days
              calculated_to = calculated_to - 1 unless product_family.cycle_of_24_hours
              ((date_from.day)..([calculated_to,to.day].min)).each do |index|
                cat_occupation[reservation.item_id][index] += reservation.quantity
              end
            end
            
            # Calculate percentage 
            cat_occupation.each do |key, value|  
              value.each do |day, occupation| 
                cat_occupation[key][day] = "#{cat_occupation[key][day]}/#{stocks[key].to_f}"
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