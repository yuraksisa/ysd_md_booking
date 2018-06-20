module Yito
  module Model
    module Booking
      module Integrity

        def self.extended(model)
          model.extend ClassMethods
        end

        module ClassMethods

          # ---------- Booking lines resources with more resources than requested -----------------------

          #
          # Get booking lines resources with more resources
          #
          def integrity_booking_lines_resource_with_more_resources

            query = <<-QUERY
              select booking_line_id, count(*)
              from bookds_bookings_lines_resources blr
              group by booking_line_id
              having count(*) > (select quantity from bookds_bookings_lines where id = booking_line_id);
            QUERY

            repository.adapter.select(query)

          end

          #
          # Resolve booking lines resource with more resources
          #
          def integrity_resolve_booking_lines_resource_with_more_resources
            query = <<-QUERY
              delete from bookds_bookings_lines_resources
              where 
                id in (
                  select id 
                  from (
                    select id 
                    from bookds_bookings_lines_resources
                    where booking_line_id in (
                      select booking_line_id
                      from bookds_bookings_lines_resources 
                      group by booking_line_id
                      having count(*) > (select quantity from bookds_bookings_lines where id = booking_line_id))
                    order by id asc) as blr
                )   
                and id not in (
                  select max_id
                  from (
                    select max(id) as max_id
                    from bookds_bookings_lines_resources 
                    where booking_line_id in (
                      select booking_line_id
                      from bookds_bookings_lines_resources 
                      group by booking_line_id
                      having count(*) > (select quantity from bookds_bookings_lines where id = booking_line_id))
                    group by booking_line_id
                  ) as blr_max    
                );
            QUERY
          end

          # ----------- Booking lines resources with less resources than requested -----------------------------



          #
          # Get integrity booking lines without resource
          #
          def integrity_booking_lines_without_resource

            query = <<-QUERY
                select booking_id, bl.id
                from bookds_bookings_lines bl
                where bl.id not in (select booking_line_id from bookds_bookings_lines_resources);
            QUERY

            repository.adapter.select(query)

          end

          #
          #
          #
          def integrity_resolve_booking_lines_without_resource

          end

        end

      end
    end
  end
end