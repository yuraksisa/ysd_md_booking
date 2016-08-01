module Yito
  module Model
    module Booking
      class MySQLActivityQueries

        def initialize(repository)
          @repository = repository
        end

        def count_received_orders(year)
 
          query = <<-QUERY
            select count(*) 
            FROM orderds_orders 
            where YEAR(creation_date) = #{year.to_i}
            QUERY

          @repository.adapter.select(query).first
        end

        def count_pending_confirmation_orders(year)

          query = <<-QUERY
            select count(distinct(o.id)) 
            FROM orderds_orders o
            JOIN orderds_order_items oi on oi.order_id = o.id
            where YEAR(creation_date) = #{year.to_i} and o.status = 1 and date > ?
            QUERY

          @repository.adapter.select(query, [Date.today.to_date]).first
        end

        def count_confirmed_orders(year)

          query = <<-QUERY
            select count(*) 
            FROM orderds_orders 
            where YEAR(creation_date) = #{year.to_i} and status IN (2)
            QUERY

          @repository.adapter.select(query).first
        end      

        def activities_by_category(year)
          
          query = <<-QUERY
            select orderds_order_items.item_id, count(*) as count  
            FROM orderds_order_items 
            JOIN orderds_orders on orderds_orders.id = orderds_order_items.order_id
            where YEAR(creation_date) = #{year.to_i} and orderds_orders.status NOT IN (1,3)
            group by orderds_order_items.item_id
            order by count desc
          QUERY

          @repository.adapter.select(query)

        end  

        def activities_by_status(year)

          query = <<-QUERY
            select CAST(status as SIGNED) status, count(*) as count  
            FROM orderds_orders 
            where YEAR(creation_date) = #{year.to_i}
            group by status
            order by count desc    
          QUERY

          @repository.adapter.select(query)

        end

        def activities_by_weekday(year)

          query = <<-QUERY
            select count(*) as count, DAYOFWEEK(creation_date) as day 
            FROM orderds_orders 
            where YEAR(creation_date) = #{year.to_i} and status <> 3
            group by day
            order by day
          QUERY

          @repository.adapter.select(query)

        end 

        def last_30_days_activities
 
          query = <<-QUERY
            SELECT DATEDIFF(CURRENT_DATE(), DATE_FORMAT(creation_date,'%Y-%m-%d')) as period, 
                   count(*) as occurrences
            FROM orderds_orders
            WHERE DATEDIFF(CURRENT_DATE(), DATE_FORMAT(creation_date,'%Y-%m-%d')) <= 30
            GROUP BY period 
          QUERY

          reservations=@repository.adapter.select(query)

        end

        #
        # Get the products total billing
        #
        def activities_billing_total(year)
          query = <<-QUERY
            select sum(orderds_order_items.item_cost) as total_cost
            FROM orderds_order_items 
            JOIN orderds_orders on orderds_orders.id = orderds_order_items.order_id
            where YEAR(orderds_order_items.date) = ? and 
                  orderds_orders.status NOT IN (1,3)         
          QUERY

          @repository.adapter.select(query, [year])
        end

        #
        # Get the total charged amount for a year
        #
        def total_charged(year)
          query = <<-QUERY
            select c.payment_method_id as payment_method, sum(c.amount) as total
            from orderds_orders o
            join orderds_order_items oi on oi.order_id = o.id
            join orderds_order_charges oc on oc.order_id = o.id
            join payment_charges c on c.id = oc.charge_id
            where o.status NOT IN (1,3) and c.status IN (4) and
                  YEAR(c.date) = ? 
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
            select sum(o.total_pending) as total, DATE_FORMAT(oi.date, '%Y-%m') as period 
            from orderds_orders o
            join orderds_order_items oi on oi.order_id = o.id
            WHERE oi.date >= '#{date_from}' and 
                  oi.date < '#{date_to}' and
                  o.status NOT IN (1,3)
            group by period
          QUERY
          @repository.adapter.select(query)
        end        

      end
    end
  end
end