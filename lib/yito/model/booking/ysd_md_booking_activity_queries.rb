module Yito
  module Model
    module Booking
      module ActivityQueries

        def self.extended(model)
          model.extend ClassMethods
        end

        module ClassMethods
          
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
                               Conditions::Comparison.new(:customer_mobile_phone, '$eq', search_text)])
            
              total = conditions.build_datamapper(::Yito::Model::Order::Order).all.count 
              data = conditions.build_datamapper(::Yito::Model::Order::Order).all(offset_order_query) 
              [total, data]
             end
          end

          def count_start(date)
            sql = <<-SQL
                   select count(distinct oi.date, oi.time, oi.item_id)
                   from orderds_orders o
                   join orderds_order_items oi on oi.order_id = o.id
                   join bookds_activities a on a.code = oi.item_id
                   where o.status in (2) and oi.date = ? 
                   group by oi.date, oi.time, oi.date_to, oi.time_to, oi.item_id, oi.item_description, a.schedule_color, a.duration_days, a.duration_hours
                   order by oi.date desc, oi.time desc, oi.item_id            
                  SQL

            programmed_activities = repository.adapter.select(sql, date).first || 0     
            
          end

          def count_received_orders(year)
            query_strategy.count_received_orders(year)
          end

          def count_pending_confirmation_orders(year)
            query_strategy.count_pending_confirmation_orders(year)
          end

          def count_confirmed_orders(year)
            query_strategy.count_confirmed_orders(year)
          end 

          #
          # Get the activity detail
          #
          def activity_detail(date, time, item_id)

            sql =<<-SQL
              select o_i.id, o_i.date, o_i.time, o_i.item_id, o_i.item_description, 
                     o_i.item_price_description,
                     o_i.quantity, o_i.item_unit_cost, o_i.item_cost, o_i.item_price_type,
                     o_i.comments,
                     o.id as order_id, o.customer_name, o.customer_surname, o.customer_email,
                     o.customer_phone, o.comments as order_comments,
                     case o.status
                       when 1 then 'pending_confirmation'
                       when 2 then 'confirmed'
                       when 3 then 'cancelled'
                     end as status,
                     a.capacity
              from orderds_order_items o_i
              join orderds_orders o on o.id = o_i.order_id
              join bookds_activities a on a.code = o_i.item_id
              where o_i.date = ? and o_i.time = ? and o_i.item_id = ?
              order by o_i.date, o_i.time, o_i.item_id, o.customer_surname, o.customer_name
            SQL

            orders = repository.adapter.select(sql, date, time, item_id)
            
            return orders

          end

          #
          # Get the activities that start on one date
          #
          def activities(date)

            sql =<<-SQL
              select o_i.id, o_i.date, o_i.time, o_i.item_id, o_i.item_description, 
                     o_i.item_price_description,
                     o_i.quantity, o_i.item_unit_cost, o_i.item_cost, o_i.item_price_type,
                     o_i.comments,
                     o.id as order_id, o.customer_name, o.customer_surname, o.customer_email,
                     o.customer_phone, o.comments as order_comments,
                     case o.status
                       when 1 then 'pending_confirmation'
                       when 2 then 'confirmed'
                       when 3 then 'cancelled'
                     end as status, 
                     a.capacity
              from orderds_order_items o_i
              join orderds_orders o on o.id = o_i.order_id
              join bookds_activities a on a.code = o_i.item_id
              where o.status NOT IN (1,3) and o_i.date = ? 
              order by o_i.date, o_i.time, o_i.item_id, o.customer_surname, o.customer_name
            SQL

            orders = repository.adapter.select(sql, date)

          end

          #
          # Get the activities summary between two dates
          #
          def activities_summary(date_from, date_to)

            sql =<<-SQL
              select o_i.id, o_i.date, o_i.time, o_i.item_id, o_i.item_description, 
                     o_i.item_price_description,
                     o_i.quantity, o_i.item_unit_cost, o_i.item_cost, o_i.item_price_type,
                     o_i.comments,
                     o.id as order_id, o.customer_name, o.customer_surname, o.customer_email,
                     o.customer_phone, o.comments as order_comments,
                     case o.status
                       when 1 then 'pending_confirmation'
                       when 2 then 'confirmed'
                       when 3 then 'cancelled'
                     end as status, 
                     a.capacity
              from orderds_order_items o_i
              join orderds_orders o on o.id = o_i.order_id
              join bookds_activities a on a.code = o_i.item_id
              where o.status NOT IN (1,3) and o_i.date >= ? and o_i.date <= ?
              order by o_i.date, o_i.time, o_i.item_id, o.customer_surname, o.customer_name
            SQL

            orders = repository.adapter.select(sql, date_from, date_to)

          end
          
          #
          # Get programmed activities between two dates.
          #
          # They represent the activities that have any confirmation
          #
          def programmed_activities(date_from, date_to)

            sql = <<-SQL
                   select oi.date, oi.time, oi.date_to, oi.time_to, oi.item_id, 
                          oi.item_description, sum(oi.quantity) as occupation,
                          a.schedule_color, a.duration_days, a.duration_hours
                   from orderds_orders o
                   join orderds_order_items oi on oi.order_id = o.id
                   join bookds_activities a on a.code = oi.item_id
                   where o.status in (2) and oi.date >= ? and oi.date <= ?
                   group by oi.date, oi.time, oi.date_to, oi.time_to, oi.item_id, oi.item_description, a.schedule_color, a.duration_days, a.duration_hours
                   order by oi.date desc, oi.time desc, oi.item_id            
                  SQL

            programmed_activities = repository.adapter.select(sql, date_from, date_to)      

          end
          
          #
          # Get the public active programmed activities
          #
          def public_programmed_activities(date_from)

            sql = <<-SQL
                   select oi.date, oi.time, oi.date_to, oi.time_to, oi.item_id, 
                          oi.item_description, sum(oi.quantity) as occupation
                   from orderds_orders o
                   join orderds_order_items oi on oi.order_id = o.id
                   join bookds_activities a on a.code = oi.item_id
                   where o.status in (2) and oi.date >= ? 
                   group by oi.date, oi.time, oi.date_to, oi.time_to, oi.item_id, 
                            oi.item_description
                   order by oi.date desc, oi.time desc, oi.item_id            
                  SQL

            programmed_activities = repository.adapter.select(sql, date_from)      


          end

          #
          # Get the occupation detail of activities that occurs once
          #
          def one_time_occupation_detail(month, year)

          end
          
          #
          # Get the occupation detail of activities that occurs multiple dates
          #
          def multiple_dates_occupation_detail(month, year)

          end
          
          #
          # Get the occupation detail of cyclic activities
          #
          def cyclic_occupation_detail(month, year)

            date_from = Date.civil(year, month, 1)
            date_to = Date.civil(year, month, -1)
            result = {}

            # Get planned activities
            condition = Conditions::JoinComparison.new('$and', 
                 [Conditions::Comparison.new(:date,'$gte', date_from),
                  Conditions::Comparison.new(:date,'$lte', date_to)
                  ])             
            planned_activities = condition.build_datamapper(::Yito::Model::Booking::PlannedActivity).all(
              :order => [:date, :time, :activity_code]
            )  

            # Build the structure
            activities = ::Yito::Model::Booking::Activity.all(active: true, occurence: :cyclic)

            activities.each do |activity|
              
              # Build item prices hash
              item_prices = {}
              if activity.number_of_item_price > 0
                (1..activity.number_of_item_price).each do |item_price|
                  item_prices.store(item_price, 0)
                end
              end
              

              # Fill with the activity turns
              activity_detail = {}
              activity.cyclic_turns_summary.each do |turn|
                # Build days hash
                days = {}
                (1..(date_to.day)).each do |day| 
                  date = Date.civil(year, month, day)
                  modified_capacity = planned_activities.select do |item|
                                        item.date.strftime('%Y-%m-%d') == date.strftime('%Y-%m-%d') and 
                                        item.time == turn and
                                        item.activity_code == activity.code
                                      end
                  real_capacity = modified_capacity.size > 0 ? modified_capacity.first.capacity : activity.capacity

                  if activity.cyclic_planned?(date.wday)
                    days.store(day, {quantity: (item_prices.empty? ? 0 : item_prices.clone),
                                     capacity: real_capacity})
                  else
                    days.store(day, {quantity: '-',
                                     capacity: real_capacity})
                  end 
                end
                activity_detail.store(turn, days) 
              end

              # Store the item
              result.store(activity.code, {name: activity.name,
                                           capacity: activity.capacity,
                                           price_literals: activity.price_definition_detail,
                                           number_of_item_price: activity.number_of_item_price,
                                           occupation: activity_detail})
            end

            # Fill with the orders

            sql =<<-SQL
              select o_i.item_id, o_i.date, o_i.time, o_i.item_price_type, sum(quantity) as quantity
              from orderds_order_items o_i
              join orderds_orders o on o.id = o_i.order_id
              join bookds_activities a on a.code = o_i.item_id 
              where o.status NOT IN (1,3) and o_i.date >= ? and o_i.date <= ? and 
                    a.occurence IN (3)
              group by o_i.item_id, o_i.date, o_i.time, o_i.item_price_type 
            SQL

            orders = repository.adapter.select(sql, date_from, date_to)

            orders.each do |order|
              if result[order.item_id] and result[order.item_id][:occupation] and
                 result[order.item_id][:occupation][order.time] and 
                 result[order.item_id][:occupation][order.time][order.date.day] and
                 result[order.item_id][:occupation][order.time][order.date.day][:quantity][order.item_price_type]
                result[order.item_id][:occupation][order.time][order.date.day][:quantity][order.item_price_type] += order.quantity
              end
            end

            # Result
            return result

          end

        end

        def pending_of_confirmation
          orders = ::Yito::Model::Order::Order.by_sql { |o| select_pending_confirmation(o) }.all(order: :creation_date)
        end

        private

        def query_strategy
      
          @query_strategy ||= 
            if DataMapper::Adapters.const_defined?(:PostgresAdapter) and repository.adapter.is_a?DataMapper::Adapters::PostgresAdapter
              PostgresqlActivityQueries.new(repository)
            else
              if DataMapper::Adapters.const_defined?(:MysqlAdapter) and repository.adapter.is_a?DataMapper::Adapters::MysqlAdapter
                MySQLActivityQueries.new(repository)
              else
                if DataMapper::Adapters.const_defined?(:SqliteAdapter) and repository.adapter.is_a?DataMapper::Adapters::SqliteAdapter
                  SQLiteActivityQueries.new(repository)
                end
              end
            end
        end        

        def select_pending_confirmation(o)
          sql = <<-QUERY
            select #{o.*} 
            FROM #{o} 
            where #{o.status} = 1 and #{o.id} in (select order_id from orderds_order_items oi where oi.date >= '#{Date.today.strftime("%Y-%m-%d")}')
            QUERY
        end

      end
    end
  end
end