module Yito
  module Model
    module Booking
      module ActivityQueries

        def self.extended(model)
          model.extend ClassMethods
        end

        module ClassMethods

          def detail(date_from, date_to)

            sql =<<-SQL
              select o_i.id, o_i.date, o_i.time, o_i.item_id, o_i.item_description, 
                     o_i.item_price_description,
                     o_i.quantity, o_i.item_unit_cost, o_i.item_cost, o_i.item_price_type,
                     o_i.comments,
                     o.id as order_id, o.customer_name, o.customer_surname, o.customer_email,
                     o.customer_phone, o.comments as order_comments,
                     o.status as status, a.capacity
              from orderds_order_items o_i
              join orderds_orders o on o.id = o_i.order_id
              join bookds_activities a on a.code = o_i.item_id
              where o.status NOT IN (1,5) and o_i.date >= ? and o_i.date <= ?
              order by o_i.date, o_i.time, o_i.item_id, o.customer_surname, o.customer_name
            SQL

            orders = repository.adapter.select(sql, date_from, date_to)

          end
          
          #
          # Get the occupation detail of activities that occurs once
          #
          def one_time_occupation_detail

          end
          
          #
          # Get the occupation detail of activities that occurs multiple dates
          #
          def multiple_dates_occupation_detail

          end
          
          #
          # Get the occupation detail of cyclic activities
          #
          def cyclic_occupation_detail(month, year)

            date_from = Date.civil(year, month, 1)
            date_to = Date.civil(year, month, -1)
            result = {}

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
              
              # Build days hash
              days = {}
              (1..(date_to.day)).each do |day| 
                date = Date.civil(year, month, day)
                if activity.cyclic_planned?(date.wday)
                  days.store(day, item_prices.empty? ? 0 : item_prices.clone)
                else
                  days.store(day, '-')
                end 
              end

              # Fill with the activity turns
              activity_detail = {}
              activity.cyclic_turns_summary.each do |turn|
                activity_detail.store(turn, days.clone) 
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
              where o.status NOT IN (1,5) and o_i.date >= ? and o_i.date <= ? and 
                    a.occurence IN (3)
              group by o_i.item_id, o_i.date, o_i.time, o_i.item_price_type 
            SQL

            orders = repository.adapter.select(sql, date_from, date_to)

            orders.each do |order|
              if result[order.item_id] and result[order.item_id][:occupation] and
                 result[order.item_id][:occupation][order.time] and 
                 result[order.item_id][:occupation][order.time][order.date.day] and
                 result[order.item_id][:occupation][order.time][order.date.day][order.item_price_type]
                result[order.item_id][:occupation][order.time][order.date.day][order.item_price_type] += order.quantity
              end
            end

            # Result
            return result

          end

        end
      end
    end
  end
end