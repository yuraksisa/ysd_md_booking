module Yito
  module Model
    module Booking
      module OccupationExtras

        def self.extended(model)
          model.extend ClassMethods
        end

        module ClassMethods

          #
          # Check the occupation of extras for a period
          #
          def extras_occupation(from, to)

            result = []
            data, detail = extras_resources_occupation(from, to)
            detail.each do |key, value|
              result << OpenStruct.new(extra_id: key, stock: value[:stock], busy: value[:occupation])
            end

            return result

          end


          # Get the extras occupation to determinate the availability
          #
          # Return a hash with the extras category and its occupation
          #
          #  - The extras categories and its occupation
          #
          #             - The key is the category code and
          #             - The value is a Hash with :
          #                 :stock               : # of stock of the extra
          #                 :occupation          : # of occupied stock of the extra (taking into account automatically assignation)
          #                 :available_stock     : # stock not assigned [id's of the items]
          #                 :assignation_pending : # assignation pending
          #
          #
          def extras_resources_occupation(date_from, date_to, category=nil)

            hours_cadency = SystemConfiguration::Variable.get_value('booking.hours_cadence','2').to_f / 24


            # 1. Build the required_extras
            #
            #    - The key is the extra_code
            #    - The valus is a Hash
            #
            #        :total                           # of resource urges for this extra (that has not been already assigned) [AFTER AUTO REASSIGN]
            #        :assignation_pending             List of reservations that requires the extra [AFTER AUTO REASSIGN]
            #        :original_total                  # of resource urges for this extra [BEFORE AUTO REASSIGN]
            #        :original_assignation_pending    List of reservations that requires the item [BEFORE AUTO REASSIGN]
            #        :reassign_total                  # of resource urges for this extra [HAVE BEEN AUTO REASSIGNED]
            #        :reassigned_assignation_pending  List of reservations that requires the extra [HAVE BEEN AUTO REASSIGNED]
            #        :stock                           is a Hash
            #                                           - The key the is the extra item reference
            #                                           - The value is an array with the assigned (+ automatically assigned) reservations
            #
            extras = ::Yito::Model::Booking::BookingExtra.all(conditions: {active: true}, fields: [:code, :max_quantity], order: [:code])

            required_extras = extras.inject({}) do |result, extra|
              result.store(extra.code, {category_stock: extra.stock,
                                        total: 0,
                                        assignation_pending: [],
                                        original_total: 0,
                                        original_assignation_pending: [],
                                        reassigned_total: 0,
                                        reassigned_assignation_pending: [],
                                        stock: {}})
              result
            end

            #
            # 2. Build the stock detail structure
            #
            stock_detail = {}

            # 2.b create dummy resources (has has not stock items)
            required_extras.each do |extra_code, extra_value|
              if extra_value[:category_stock] > extra_value[:stock].size
                ((extra_value[:stock].size+1)..extra_value[:category_stock]).each do |idx|
                  stock_id = "DUMMY-#{extra_code}-#{idx}"
                  # Add dummy resource to the category stock detail
                  extra_value[:stock].store(stock_id, [])
                  # Add dummy resource to the stock detail
                  stock_detail.store(stock_id, {category: extra_code,
                                                available: true,
                                                estimation: []})
                end
              end
            end

            #
            # 3. Fill with reservations urges
            #
            extras_urges = extras_urges(date_from, date_to)
            extras_urges.each do |extra_urge|
              extra_urge.instance_eval { class << self; self end }.send(:attr_accessor, :preassigned_item_reference)
              # Not assigned resource stock
              if required_extras.has_key?(extra_urge.extra_id)
                required_extras[extra_urge.extra_id][:total] += 1
                required_extras[extra_urge.extra_id][:assignation_pending] << extra_urge
              end
            end

            #
            # 4. Try to automatically assign stock to assignation pending (extras_urges)
            #
            required_extras.each do |required_extra_key, required_extra_value|

              required_extras[required_extra_key][:original_total] = required_extras[required_extra_key][:total]
              required_extras[required_extra_key][:original_assignation_pending] = required_extras[required_extra_key][:assignation_pending].clone

              # Clones the assignation pending resource urges (because we are going to manipulate it)
              assignation_pending_sources = required_extra_value[:assignation_pending].clone
              assignation_pending_sources.each do |assignation_pending_source|
                # Search stock items candidates
                candidates = required_extra_value[:stock].select do |item_reference, item_reference_assigned_reservations|
                  item_reference_assigned_reservations.all? do |assigned|
                    assign_pend_d_f = parse_date_time_from(assignation_pending_source.date_from, assignation_pending_source.time_from)
                    assign_pend_d_t = parse_date_time_to(assignation_pending_source.date_to, assignation_pending_source.time_to)
                    assigned_d_f = parse_date_time_from(assigned.date_from, assigned.time_from)
                    assigned_d_t = parse_date_time_from(assigned.date_to, assigned.time_to)
                    assignation_pending_source.date_to < (assigned.date_from - hours_cadency) || assignation_pending_source.date_from > (assigned.date_to + hours_cadency)
                  end
                end

                if candidates.size > 0
                  candidate_item_reference = candidates.keys.first
                  # Apply reassignation
                  required_extra_value[:total] -= 1
                  required_extra_value[:assignation_pending].delete(assignation_pending_source)
                  # Holds for history
                  required_extra_value[:reassigned_total] += 1
                  required_extra_value[:reassigned_assignation_pending] << assignation_pending_source
                  # Append the assignation pending to the stock assigned
                  required_extra_value[:stock][candidate_item_reference] << assignation_pending_source
                  required_extra_value[:stock][candidate_item_reference].sort! {|x,y| x.date_from <=> y.date_from }
                  if stock_detail.has_key?(candidate_item_reference)
                    stock_detail[candidate_item_reference][:estimation] << assignation_pending_source
                  end
                  assignation_pending_source.preassigned_item_reference = candidate_item_reference
                  stock_detail[candidate_item_reference][:available] = false
                end

              end

            end
            #
            #
            #
            extras_occupation = {}

            request_date_from =parse_date_time_from(date_from)
            request_date_to = parse_date_time_to(date_to)

            required_extras.each do |required_extra_key, required_extra_value|

              stock = required_extra_value[:category_stock]
              occupation = (stock_detail.select {|k,v| v[:category] == required_extra_key && (!v[:estimation].empty?) }).keys.count
              available_stock = (stock_detail.select {|k,v| v[:category] == required_extra_key && v[:estimation].empty? }).keys
              automatically_preassigned_stock = (stock_detail.select {|k,v| v[:category] == required_extra_key && !v[:estimation].empty? }).keys
              available_assignable_resource = (stock_detail.select do
              |k,v| v[:category] == required_extra_key && v[:estimation].empty? && stock_detail[k][:assignable]
              end).keys.count
              # If there is not stock, check if there are available assignable resources in order to admit reservations
              stock = occupation + available_assignable_resource if (stock <= occupation)

              extras_occupation.store(required_extra_key,
                                      {stock: stock,
                                       occupation: occupation,
                                       available_stock: available_stock ,
                                       automatically_preassigned_stock: automatically_preassigned_stock,
                                       assignation_pending: required_extra_value[:assignation_pending]})

            end

            return [stock_detail, extras_occupation]

          end


          #
          # Get the extras urges in a date range (including reservations)
          #
          def extras_urges(date_from, date_to)
            query = extras_occupation_query(date_from, date_to)
            extras_occupations = repository.adapter.select(query)
          end

          private

          #
          # Check the extras that are assigned for day
          #
          def extras_occupation_query(from, to, options=nil)

            extra_condition = ''

            unless options.nil?
              if options.has_key?(:mode)
                if options[:mode] == 'extra' and options.has_key(:extra)
                  extra_condition = "and e.extra_id = #{options[:product]}"
                end
              end
            end

            date_diff_reservations = query_strategy.date_diff('b.date_from', 'b.date_to', 'days')

            query = <<-QUERY
              SELECT * 
              FROM (
                SELECT e.extra_id,
                       b.id,
                       b.date_from, b.time_from,
                       b.date_to, b.time_to,
                       #{date_diff_reservations},
                       CONCAT(b.customer_name, ' ', b.customer_surname) as title,
                       b.planning_color
                FROM bookds_bookings b
                JOIN bookds_bookings_extras e on e.booking_id = b.id
                WHERE ((b.date_from <= '#{from}' and b.date_to >= '#{from}') or 
                   (b.date_from <= '#{to}' and b.date_to >= '#{to}') or 
                   (b.date_from = '#{from}' and b.date_to = '#{to}') or
                   (b.date_from >= '#{from}' and b.date_to <= '#{to}')) and
                    b.status NOT IN (1,5) #{extra_condition}
              ) AS D                    
              ORDER BY extra_id, date_from
            QUERY

          end

        end

      end
    end
  end
end