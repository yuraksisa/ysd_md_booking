module Yito
  module Model
    module Booking
      class SqliteActivityQueries

        def initialize(repository)
          @repository = repository
        end

        def count_received_orders(year)
 
          query = <<-QUERY
            select count(*) 
            FROM orderds_orders 
            where strftime('%Y', creation_date) = #{year.to_i}= #{year.to_i}
            QUERY

          @repository.adapter.select(query).first
        end

        def count_pending_confirmation_orders(year)

          query = <<-QUERY
            select count(distinct(o.id)) 
            FROM orderds_orders o
            JOIN orderds_order_items oi on oi.order_id = o.id
            where strftime('%Y', creation_date) = #{year.to_i} = #{year.to_i} and o.status = 1 and date > ?
            QUERY

          @repository.adapter.select(query, [Date.today.to_date]).first
        end

        def count_confirmed_orders(year)

          query = <<-QUERY
            select count(*) 
            FROM orderds_orders 
            where strftime('%Y', creation_date) = #{year.to_i} = #{year.to_i} and status IN (2)
            QUERY

          @repository.adapter.select(query).first
        end     

      end
    end
  end
end