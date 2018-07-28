module Yito
  module Model
    module Booking
      module Planning

        def self.extended(model)
          model.extend ClassMethods
        end

        #
        # Methods summary:
        #
        # - planning : Planning information
        # - resources_with_reservation : Resources with reservations for planning rows
        # - planning_resources : List of resources for the planning rows
        #
        # - overbooking_conflicts
        # - returned_delivered_same_day_resources
        #
        module ClassMethods

          #
          # Resources with reservation
          # -----------------------------------------------------------------------------------------------------
          #
          # Get the resources with reservation during the period. It's used to get planning resources
          #
          # == Parameters::
          # from::
          #   The starting date
          # to::
          #   The ending date
          #
          # == Result
          #   Array of object with the following attributes:
          #
          #   item_reference -> The reference
          #   item_id        -> The requested category
          #   item_category  -> The reference category
          #
          def resources_with_reservation(from, to)
            query = <<-QUERY
                select distinct(bookds_bookings_lines_resources.booking_item_reference) as item_reference,
                       bookds_bookings_lines.item_id as item_id,
                       bookds_bookings_lines_resources.booking_item_category as item_category   
                FROM bookds_bookings_lines_resources
                JOIN bookds_bookings_lines on bookds_bookings_lines_resources.booking_line_id = bookds_bookings_lines.id
                JOIN bookds_bookings on bookds_bookings.id = bookds_bookings_lines.booking_id
                where ((bookds_bookings.date_from <= '#{from}' and bookds_bookings.date_to >= '#{from}') or 
                       (bookds_bookings.date_from <= '#{to}' and bookds_bookings.date_to >= '#{to}') or 
                       (bookds_bookings.date_from = '#{from}' and bookds_bookings.date_to = '#{to}') or
                       (bookds_bookings.date_from >= '#{from}' and bookds_bookings.date_to <= '#{to}')) and
                      status NOT IN (1,5) and 
                      bookds_bookings_lines_resources.booking_item_reference is not NULL
                order by bookds_bookings_lines_resources.booking_item_reference
            QUERY

            repository.adapter.select(query)
          end

          #
          # Planning resources
          # ------------------------------------------------------------------------------------------------------
          #
          # Get planning resources
          #
          # == Parameters::
          # date_from::
          #   The starting date
          # date_to::
          #   The ending date
          # options::
          #   A hash with some options in order to filter the results
          #   :mode -> :stock or :product
          #   :reference -> If mode is :stock, the resource reference
          #   :product -> If mode is :product, the category
          #
          def planning_resources(date_from, date_to, options=nil)

            current_year = DateTime.now.year
            references = []
            references_hash = {}

            # Current stock

            if !options.nil? and options[:mode] == :stock and options.has_key?(:reference) # Reference
              references << options[:reference]
              if item = ::Yito::Model::Booking::BookingItem.get(options[:reference])
                references_hash.store(item.reference, item.category_code)
              else
                references_hash.store(options[:reference], nil)
              end
            elsif !options.nil? and options[:mode] == :product and options.has_key?(:product) # Product references
              ::Yito::Model::Booking::BookingItem.all(
                  :conditions => {category_code: options[:product], active: true},
                  :fields => [:reference, :category_code],
                  :order =>  [:planning_order, :category_code, :reference]).each do |item|
                references << item.reference
                references_hash.store(item.reference, item.category_code)
              end
            else # All
              ::Yito::Model::Booking::BookingItem.all(
                  :conditions => {active: true},
                  :fields => [:reference, :category_code],
                  :order =>  [:planning_order, :category_code, :reference]).each do |item|
                references << item.reference
                references_hash.store(item.reference, item.category_code)
              end
            end

            # Historic stock (from assigned reservations)

            historic_resources = BookingDataSystem::Booking.resources_with_reservation(date_from, date_to)
            historic_resources_hash = historic_resources.inject({}) do |result, item|
              result.store(item.item_reference, item.item_category) unless result.has_key?(item.item_reference)
              result
            end

            # Append the historic stock

            if !options.nil? and options[:mode] == :product and options.has_key?(:product) # Product
              historic_resources_hash.each do |key, value|
                if value == options[:product]
                  references << key unless references.include?(key)
                  references_hash.store(key, value) unless references_hash.has_key?(key)
                end
              end
            else
              historic_resources.each do |item|
                references << item.item_reference unless references.include?(item.item_reference)
              end
              historic_resources_hash.each do |key, value|
                references_hash.store(key, value) unless references_hash.has_key?(key)
              end
            end

            # Historic stock blocking (from stock blocking)

            #p "references: #{references_hash.inspect}"

            return [references, references_hash]
          end


          #
          # Planning reservations and stock blocking
          # ---------------------------------------------------------------------------------------------------------
          #
          # Get references to build the rows and the reservations and stock blockings to be shown in a planning between
          # two dates
          #
          # Updated 2018-07-27
          #
          # - Automatically assign not assigned pending of confirmation reservations in order to be shown in the
          #   planning
          #
          # Parameters::
          #
          # date_from::
          #   The starting date
          # date_to::
          #   The ending date
          # options::
          #   A hash with some options in order to filter the results
          #   :mode -> :stock or :product
          #   :reference -> If mode is :stock, the resource reference
          #   :product -> If mode is :product, the category
          #   :include_future_pending_confirmation -> If true it returns future pending of confirmation reservations
          #
          # Returns::
          #
          # A Hash with two keys :
          #
          #  references: Hash which key is the reference and the value is the category
          #          {
          #            "K1-01" : "K1"
          #          }
          #  result: An array with the reservations and stock blockings
          #          [
          #              {
          #               "booking_item_reference":"K1-01",
          #               "item_id":"K1",
          #               "requested_item_id":"K1",
          #               "id":22,
          #               "origin":"booking",
          #               "date_from":"2018-08-01",
          #               "time_from":"10:00",
          #               "date_to":"2018-08-13",
          #               "time_to":"20:00",
          #               "days":12,
          #               "title":"Cersei Lannister",
          #               "detail":null,
          #               "id2":50,
          #               "planning_color":"#66ff66",
          #               "notes":null,
          #               "confirmed":0
          #               }
          #          ]
          #
          #
          def planning(date_from, date_to, options=nil)

            # 1. Get the stock
            references, references_hash = planning_resources(date_from, date_to, options)

            # 2. Get the reservations
            query = resources_occupation_query(date_from, date_to, options)
            resource_occupations = repository.adapter.select(query)

            # 3. Automatically assign not assigned pending confirmation reservations
            # TODO "Not assigned confirmed"
            not_assigned = resource_occupations.select { |resource_occupation| resource_occupation.booking_item_reference.nil? } # resource_occupation.confirmed == 0
            if not_assigned.size > 0
              automatically_assigned = []
              not_assigned.each do |not_assigned_item|
                # Search for availability
                stock_detail, category_occupation = BookingDataSystem::Booking.categories_availability(not_assigned_item.date_from,
                                                                                                       not_assigned_item.time_from,
                                                                                                       not_assigned_item.date_to,
                                                                                                       not_assigned_item.time_to,
                                                                                                       not_assigned_item.item_id,
                                                                                                       {
                                                                                                           origin: not_assigned_item.origin,
                                                                                                           id: not_assigned_item.id
                                                                                                       })
                # Check if there is an assignable stock
                assignable_stock = category_occupation[not_assigned_item.item_id][:available_assignable_stock] - automatically_assigned
                # Assign it
                unless assignable_stock.empty?
                  booking_item_reference = assignable_stock.first
                  not_assigned_item.booking_item_reference = booking_item_reference
                  not_assigned_item.requested_item_id = not_assigned_item.item_id
                  not_assigned_item.auto_assigned_item_reference = 1
                  automatically_assigned << booking_item_reference
                end

              end
            end

            # 4. Prepare the dates (in strings) for the planning
            resource_occupations.each do |item|
              item.date_from = item.date_from.strftime('%Y-%m-%d')
              item.date_to = item.date_to.strftime('%Y-%m-%d')
            end

            p "resource_occupations:#{resource_occupations.inspect}"

            # 5. Build the results
            {references: references_hash, result: resource_occupations}
          end


          # --------------------------- Overbooking conflicts ----------------------------------------------------

          #
          # Get the resources that are returned and delivered the same day
          #
          def returned_delivered_same_day_resources
            today = Date.today
            data = repository.adapter.select(query_overbooking_conflicts, today, today, today, today).map do |item|
              value = {}
              if item.date_from_1 > item.date_from_2
                value['booking_id_1'] = item.booking_id_2
                value['date_from_1'] = item.date_from_2
                value['time_from_1'] = item.time_from_2
                value['date_to_1'] = item.date_to_2
                value['time_to_1'] = item.time_to_2
                value['resource_id_1'] = item.resource_id_2
                value['booking_item_reference_1'] = item.booking_item_reference_2
                value['booking_id_2'] = item.booking_id_1
                value['date_from_2'] = item.date_from_1
                value['time_from_2'] = item.time_from_1
                value['date_to_2'] = item.date_to_1
                value['time_to_2'] = item.time_to_1
                value['resource_id_2'] = item.resource_id_1
                value['booking_item_reference_2'] = item.booking_item_reference_1
                OpenStruct.new(value)
              else
                item
              end
            end
          end

          #
          # Check overbooking conflicts
          #
          def overbooking_conflicts

            returned_delivered_same_day_resources.select do |item|
              begin
                t1 = DateTime.strptime(item.time_to_1,"%H:%M")
                t2 = DateTime.strptime(item.time_from_2,"%H:%M")
                diff = ((t2 - t1).to_f * 24).to_i
                diff < 2
              rescue
                true
              end
            end

          end

        end

      end
    end
  end
end