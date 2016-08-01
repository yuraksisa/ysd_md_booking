module Yito
  module Model
    module Booking
      class PostgresqlActivityQueries

        def initialize(repository)
          @repository = repository
        end

        #
        # Booking text search
        #
        def text_search(search_text, offset_order_query)
          ::Yito::Model::Order::Order.by_sql{ |b| [text_search_query(b,search_text)] }.all(offset_order_query)
        end

        def count_text_search(search_text)
          query = <<-QUERY
            select count(*) 
            FROM orderds_orders 
            where id = #{search_text.to_i} or
                  customer_email = '#{search_text}' or 
                  customer_phone = '#{search_text}' or 
                  customer_mobile_phone = '#{search_text}' or
                  unaccent(customer_surname) ilike unaccent('%#{search_text}%') or
                  unaccent(customer_name) ilike unaccent('%#{search_text}%')
          QUERY
          @repository.adapter.select(query).first
        end

        def count_received_orders(year)
 
          query = <<-QUERY
            select count(*) 
            FROM orderds_orders 
            where date_part('year', creation_date) = #{year.to_i} 
            QUERY

          @repository.adapter.select(query).first
        end

        def count_pending_confirmation_orders(year)

          query = <<-QUERY
            select count(distinct(o.id)) 
            FROM orderds_orders o
            JOIN orderds_order_items oi on oi.order_id = o.id
            where date_part('year', creation_date) = #{year.to_i} and o.status = 1 and date > ?
            QUERY

          @repository.adapter.select(query, [Date.today.to_date]).first
        end

        def count_confirmed_orders(year)

          query = <<-QUERY
            select count(*) 
            FROM orderds_orders 
            where date_part('year', creation_date) = #{year.to_i} and status IN (2)
            QUERY

          @repository.adapter.select(query).first
        end    

        def activities_by_category(year)
          
          query = <<-QUERY
            select orderds_order_items.item_id, count(*) as count  
            FROM orderds_order_items 
            JOIN orderds_orders on orderds_orders.id = orderds_order_items.order_id
            where date_part('year', creation_date) = #{year.to_i} and orderds_orders.status NOT IN (1,3)
            group by orderds_order_items.item_id
            order by count desc
          QUERY

          @repository.adapter.select(query)

        end

        def activities_by_status(year)

          query = <<-QUERY
            select status, count(*) as count  
            FROM orderds_orders 
            where date_part('year', creation_date) = #{year.to_i}
            group by status
            order by count desc
          QUERY

          @repository.adapter.select(query)

        end

        def activities_by_weekday(year)

          query = <<-QUERY
            select count(*), date_part('DOW', creation_date) as day 
            FROM orderds_orders 
            where date_part('year', creation_date) = #{year.to_i} and status <> 5
            group by day
            order by day
          QUERY

          @repository.adapter.select(query)

        end 


        def last_30_days_activities
 
          query = <<-QUERY
             SELECT (now()::date - creation_date::date) as period, 
             count(*) as occurrences
             FROM orderds_orders
             WHERE creation_date >= (now() - INTERVAL '30 day')
             GROUP BY period 
             order by period desc
          QUERY

          reservations=@repository.adapter.select(query)

        end

        #
        # Get the activities total billing
        #
        def activities_billing_total(year)
          query = <<-QUERY
            select sum(orderds_order_items.item_cost) as total_cost
            FROM orderds_order_items 
            JOIN orderds_orders on orderds_orders.id = orderds_order_items.order_id
            where date_part('year', orderds_order_items.date) = ? and 
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
            select sum(o.total_pending) as total, TO_CHAR(oi.date, 'YYYY-MM') as period 
            from orderds_orders o
            join orderds_order_items oi on oi.order_id = o.id
            WHERE oi.date >= '#{date_from}' and 
                  oi.date < '#{date_to}' and
                  o.status NOT IN (1,3)
            group by period
          QUERY
          @repository.adapter.select(query)
        end 

        private

        def text_search_query(o,search_text)
          query = <<-QUERY
            select #{o.*} FROM #{o} 
            where #{o.id} = #{search_text.to_i} or
                  #{o.customer_email} = '#{search_text}' or 
                  #{o.customer_phone} = '#{search_text}' or 
                  #{o.customer_mobile_phone} = '#{search_text}' or
                  unaccent(#{o.customer_surname}) ilike unaccent('#{search_text}%') or
                  unaccent(#{o.customer_name}) ilike unaccent('#{search_text}%')
          QUERY

        end 

      end
    end
  end
end