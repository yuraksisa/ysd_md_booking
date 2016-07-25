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