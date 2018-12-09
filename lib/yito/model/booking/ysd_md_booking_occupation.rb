module Yito
  module Model
    module Booking
      module Occupation

        def self.extended(model)
          model.extend ClassMethods
        end

        #
        # Methods summary:
        #
        # = Checking occupation and availability
        #
        # - occupation : Categories occupation
        # - resources_occupation : Occupation detail
        # - resources_urges : Reservations and Prereservations
        #
        # = Monthly occupation statistics
        #
        # - historic_products :
        # - monthly_occupation :
        #
        # = Daily availability
        #
        # - category_daily_detailed_period_occupation
        #
        module ClassMethods

          #
          # Check if the availability is managed by storage or globally
          #
          # It depends on the product family definition + the multiple_rental_locations and resource_availability_by_rental_location_storage settings
          #  
          # == Returns:
          #
          #   true if the availability is managed by storage
          #   false if the availability is managed globally
          #  
          def availability_managed_by_storage
            
            @product_family = ::Yito::Model::Booking::ProductFamily.get(SystemConfiguration::Variable.get_value('booking.item_family')) 
            if (@product_family and @product_family.multiple_locations and @product_family.multiple_storages)
                @multiple_rental_locations = SystemConfiguration::Variable.get_value('booking.multiple_rental_locations', 'false').to_bool
                @availability_by_storage = SystemConfiguration::Variable.get_value('booking.resource_availability_by_rental_location_storage', 'false').to_bool
                return (@multiple_rental_locations and @availability_by_storage)
            else
                return false
            end   

          end  

          #
          # Check if the are multiple rental locations
          #  
          # It depends on the product family definition + the multiple_rental_locations setting  
          #  
          # == Returns:
          #
          #   true if there are multiple rental locations
          #   false if there are not multiple rental locations
          #  
          def multiple_rental_locations

            @product_family = ::Yito::Model::Booking::ProductFamily.get(SystemConfiguration::Variable.get_value('booking.item_family'))
            @multiple_rental_locations = SystemConfiguration::Variable.get_value('booking.multiple_rental_locations', 'false').to_bool
            result = (@product_family and @product_family.multiple_locations and @multiple_rental_locations)
            return result
          
          end  

          #
          # Check if there are multiple rental locations and categories are exclusive for each location
          #
          # It allows to use the platform as an multi-user or multi-company reservation system. Each user(supplier) has a rental_location with
          # exclusive categories 
          #
          #
          # == Returns:
          #
          #   :not_multiple_rental_locations
          #   :multiple_rental_locations_not_exclusive_categories
          #   :multiple_rental_locations_exclusive_categories
          # 
          #          
          def multiple_rental_locations_exclusive_categories

            @product_family = ::Yito::Model::Booking::ProductFamily.get(SystemConfiguration::Variable.get_value('booking.item_family'))
            @multiple_rental_locations = SystemConfiguration::Variable.get_value('booking.multiple_rental_locations', 'false').to_bool
            
            if @product_family and @product_family.multiple_locations and @multiple_rental_locations
              if @exclusive_categories_for_location = SystemConfiguration::Variable.get_value('booking.multiple_rental_locations', 'false').to_bool
                return :multiple_rental_locations_exclusive_categories
              else
                return :multiple_rental_locations_not_exclusive_categories
              end    
            else
              return :not_multiple_rental_locations
            end    
            
          end  

          # 
          # Check if the pickup and return places must belong to the same rental location
          #
          # It depends on the product family definition + the multiple_rental_locations and multiple_rental_locations_pickup_return_same_location settings  
          #  
          # == Returns:
          #
          #   true if the pickup and return must belong to the same rental location
          #   false if the pickup and return mustn't belong to the same rental location
          #
          def pickup_return_places_same_rental_location

            @same_location = SystemConfiguration::Variable.get_value('booking.multiple_rental_locations_pickup_return_same_location', 'false').to_bool

            (multiple_rental_locations and @same_location)

          end

          #
          # Categories availability summary
          # -------------------------------------------------------------------------------------------------------
          #
          #  Categories availability summary. For any category, get the stock, the busy resources and a detail of the
          #  available resources. It uses the
          #
          # == Parameters:
          #
          # rental_location_code::
          #   The rental location code                
          # date_from::
          #   The reservation starting date
          # time_from::
          #   The reservation starting time
          # date_to::
          #   The reservation ending date
          # time_to::
          #   The reservation ending time
          # category_code::
          #   The category code (or nil for all categories)
          # ignore_urge::
          #   A hash with some options
          #   :origin -> 'booking' or 'prereservation'
          #   :id -> The id of the booking or prereservation
          # include_stock::
          #   Boolean to include the free resources or not
          #
          # == Returns:
          #
          # Array of Object with the following properties:
          #
          #   item_id   -> Category
          #   stock     -> Category total stock
          #   busy      -> Category occupation (in units)
          #   available -> Is available or not
          #   resources -> Array of references of available resources
          #
          def categories_availability_summary(rental_location_code,
                                              date_from, time_from, date_to, time_to,
                                              category_code = nil,
                                              ignore_urge=nil,
                                              include_stock=false)

            result = []

            data, detail = categories_availability(rental_location_code,
                                                   date_from, time_from,
                                                   date_to, time_to,
                                                   nil, ignore_urge)
            detail.each do |key, value|
              if include_stock
                result << OpenStruct.new(item_id: key,
                                         stock: value[:stock],
                                         busy: value[:occupation],
                                         available: (value[:stock] > value[:occupation]),
                                         resources: value[:available_assignable_stock])
              else
                result << OpenStruct.new(item_id: key,
                                         stock: value[:stock],
                                         busy: value[:occupation],
                                         available: (value[:stock] > value[:occupation]))
              end
            end

            unless category_code.nil?
              result.select! { |item| item.item_id == category_code }
            end

            return result

          end

          #
          # Categories availability
          # --------------------------------------------------------------------------------------------------------
          #
          # Summary information of categories availability for a period (date_from-time_from to date_to-time_to) and
          # the free resources
          #
          # Updated 2018.07.27
          #
          # - Take into account reservations that are returned and delivered again in the same day if the hours between
          #   them is the minimum required to prepare the resource
          #
          # - Take into account future pending reservations. While a future reservation in pending of confirmation it
          #   has a reserved resource and can be managed in the planning
          #
          # == Parameters:
          # rental_location_code::
          #   The rental location code            
          # date_from::
          #   The reservation starting date
          # time_from::
          #   The reservation starting time
          # date_to::
          #   The reservation ending date
          # time_to::
          #   The reservation ending time
          # category::
          #   The requested category code or nil form all categories
          # ignore_urge::
          #   A hash with some options
          #   :origin -> 'booking' or 'prereservation'
          #   :id -> The id of the booking or prereservation
          #
          # == Returns:
          #
          # Return an array with two elements
          #
          #  - First  : stock_detail. (Hash) The stock, availability and assigned sources
          #
          #             - The key is the stock resource id
          #             - The value is a Hash with :
          #                 :category        : The product category
          #                 :own_property    : The product belongs to the company
          #                 :assignable      : The product allow assignation
          #                 :available       : Boolean that says the is available or not
          #                 :detail          : Assigned reservations
          #                 :estimation      : Automatically assigned reservations
          #                 :real_stock      : It's real stock or dummy to manage not defined resources
          #
          #  - Second : category_occupation. (Hash) The products categories and its occupation
          #
          #             - The key is the category code and
          #             - The value is a Hash with :
          #                 :stock               : # of stock in the category
          #                 :occupation [urges]  : # of occupied stock in the category (taking into account automatically assignation)
          #                 :occupation_assigned : # of assigned urges
          #                 :available_stock     : # stock not assigned [id's of the items]
          #                 :available_assignable_stock : # stock not assigned and available [id's of the items]
          #                 :assignation_pending : Original assignation pending
          #                 :pending_confirmation_assignation_pending : Original assignation pending that corresponds a pending confirmation urges
          #                 :confirmed_assignation_pending : Original assignation pending that corresponds a confirmed urges
          #                 :pending_confirmation_assignation_pending_after_preassign : Pending of confirmation urges not reassigned
          #                 :confirmed_assignation_pending_after_preassign : Confirmed urges not reassigned
          #                 :pending_confirmation_reassigned : Pending of confirmation urges reassigned
          #                 :confirmed_reassigned : Confirmed urges reassigned
          #
          #
          def categories_availability(rental_location_code, date_from, time_from, date_to, time_to, category=nil, ignore_urge=nil)

             product_family = ::Yito::Model::Booking::ProductFamily.get(SystemConfiguration::Variable.get_value('booking.item_family'))

             if product_family and product_family.product_type == :resource 
                categories_availability_by_resource(rental_location_code, date_from, time_from, date_to, time_to, category, ignore_urge)              
             else
                categories_availability_by_category(rental_location_code, date_from, time_from, date_to, time_to, category, ignore_urge)
             end 

          end


          #
          # Resource urges
          # ---------------------------------------------------------------------------------------------------------
          #
          # Get the confirmed reservations and stock blockings in a range of dates.
          #
          # By default it retrieve all, but the result can be filtered by a category or a resource [stock item]
          #
          # == Parameters:
          # date_from::
          #   The reservation starting date
          # date_to::
          #   The reservation ending date
          # options::
          #   A hash with some options in order to filter the results
          #   :mode -> :stock or :product
          #   :reference -> If mode is :stock, the resource reference
          #   :product -> If mode is :product, the category
          #   :include_future_pending_confirmation -> If true it includes future pending confirmation reservations
          #
          # == Returns:
          #
          # Array with the detail of the reservation and the assigned resource (in case there is an assigned one)
          #
          #   booking_item_reference -> Resource id
          #   item_id -> The resource category
          #   requested_item_id -> The customer required category
          #   id -> The id
          #   origin -> The origin : 'booking' or 'prereservation'
          #   date_from -> Starting date
          #   time_from -> Starting time
          #   date_to -> Ending date
          #   time_to -> Ending time
          #   days -> # of days
          #   title -> Title : customer name
          #   detail -> Resource information
          #   id2 -> Id of the reservation line resource o prereservation line
          #   planning_color -> Color to represent the reservation in the planning
          #   notes -> Internal notes
          #
          def resource_urges(date_from, date_to, options=nil)
            query = query_strategy.resources_occupation_query(date_from, date_to, options)
            resource_occupations = repository.adapter.select(query)
          end

          # --------------------------- Occupation summary -------------------------------------------------------

          #
          # Historic products
          # ------------------------------------------------------------------------------------------------------
          #
          # Get the products (or categories) that where booked in a year
          #
          def historic_products(year)

            data = query_strategy.historic_products(year)

          end

          #
          # Monthly occupation
          # ---------------------------------------------------------------------------------------------------------
          #
          # Get the detailed information of monthly occupation
          #
          # == Parameters:
          # month::
          #   From 1 to 12
          # year::
          #   The year
          # category::
          #   The category code or nil for all category
          #
          # == Returns:
          #
          def monthly_occupation(month, year, category=nil)

            from = Date.civil(year, month, 1)
            to = Date.civil(year, month, -1)

            year = from.year
            month = from.month
            current_year = DateTime.now.year
            product_family = ::Yito::Model::Booking::ProductFamily.get(SystemConfiguration::Variable.get_value('booking.item_family'))

            # Get products stocks
            if current_year == year
              conditions = category.nil? ? {} : {code: category}
              categories = ::Yito::Model::Booking::BookingCategory.all(conditions: conditions.merge({active: true}), fields: [:code, :stock])
              stocks = categories.inject({}) do |result, item|
                result.store(item.code, item.stock)
                result
              end
            else
              categories = BookingDataSystem::Booking.historic_products(year).map do |item|
                OpenStruct.new({code: item, stock: 0})
              end
              stocks = categories.inject({}) do |result, item|
                stock = if h_b_c = ::Yito::Model::Booking::BookingCategoryHistoric.first(category_code: item.code, year: year)
                          h_b_c.stock
                        else
                          if b_c = ::Yito::Model::Booking::BookingCategory.get(item.code)
                            b_c.stock
                          else
                            0
                          end
                        end
                result.store(item.code, stock)
                result
              end
            end
            stocks.store(:total, stocks.values.inject(0) {|result, item| result+=item })

            # Build products occupation
            cat_occupation = categories.map{|item| item.code}.concat([:total]).inject({}) do |result, item|
              days_hash = {}
              ((from.day)..(to.day)).each do |day|
                days_hash.store(day, {items:[], occupation:0, occupied: 0, total: stocks[item], percentage:0})
              end
              days_hash.store(:total, {occupation:0, occupied: 0, total: 0, percentage:0})
              result.store(item, days_hash)
              result
            end

            # Query bookings for the period
            query = occupation_query(from, to)

            reservations = repository.adapter.select(query)

            # Fill products occupation
            reservations.each do |reservation|
              date_from = reservation.date_from
              date_to = reservation.date_to
              calculated_from = date_from.month < month ? 1 : date_from.day
              calculated_to = date_to.month > month ? to.day : date_to.day
              (calculated_from..calculated_to).each do |index|
                unless reservation.booking_item_reference.nil?
                  if cat_occupation.has_key?(reservation.item_id) and cat_occupation[reservation.item_id].has_key?(index)
                    unless cat_occupation[reservation.item_id][index][:items].include?(reservation.booking_item_reference)
                      cat_occupation[reservation.item_id][index][:items] << reservation.booking_item_reference
                    end
                  end
                end
                cat_occupation[reservation.item_id][index][:occupied] += reservation.quantity if cat_occupation.has_key?(reservation.item_id) and
                    cat_occupation[reservation.item_id].has_key?(index)
              end
            end

            # Calculate occupation representation and percentage
            cat_occupation.each do |key, value|
              value.each do |day, occupation|
                if cat_occupation[key][day][:total] > 0
                  cat_occupation[key][day][:occupation] = "#{cat_occupation[key][day][:occupied]}/#{cat_occupation[key][day][:total]}"
                  cat_occupation[key][day][:percentage] = (cat_occupation[key][day][:occupied].to_f / cat_occupation[key][day][:total].to_f * 100).round
                else
                  cat_occupation[key][day][:occupation] = '-'
                  cat_occupation[key][day][:percentage] = 0
                end
              end
            end

            # Calculate total column
            cat_occupation.each do |key, value|
              value.each do |day, occupation|
                next if day == :total
                cat_occupation[key][:total][:occupied] += occupation[:occupied]
                cat_occupation[key][:total][:total] += occupation[:total]
                if cat_occupation[key][:total][:total] > 0
                  cat_occupation[key][:total][:percentage] = (cat_occupation[key][:total][:occupied].to_f / cat_occupation[key][:total][:total].to_f * 100).round
                end
              end
            end

            # Calculate total row
            ((from.day)..(to.day)).each do |day|
              cat_occupation.each do |key, value|
                next if key == :total
                cat_occupation[:total][day][:occupied] += value[day][:occupied]
                if cat_occupation[:total][day][:total] > 0
                  cat_occupation[:total][day][:percentage] = (cat_occupation[:total][day][:occupied].to_f / cat_occupation[:total][day][:total].to_f * 100).round
                end
              end
            end

            ((from.day)..(to.day)).each do |day|
              cat_occupation[:total][:total][:occupied] += cat_occupation[:total][day][:occupied]
              if cat_occupation[:total][:total][:total] > 0
                cat_occupation[:total][:total][:percentage] = (cat_occupation[:total][:total][:occupied].to_f / cat_occupation[:total][:total][:total].to_f * 100).round
              end
            end

            cat_occupation


          end

          # ----------------------------------- Daily detailed information -------------------------------------------

          #
          # Category daily detailed period occupation
          # ----------------------------------------------------------------------------------------------------------
          #
          # Get the occupation detail and availability day by day of product category in a period
          #
          # == Parameters:
          #
          # from::
          #   The starting date
          # to::
          #   The ending date
          # category::
          #   The category : Nil for all categories
          #
          # == Returns:
          #
          # {"2018-Dic-25":{"occupied":0,"total":4},
          #  "2018-Dic-26":{"occupied":0,"total":4}
          #
          def category_daily_detailed_period_occupation(from, to, category=nil)

            months = ['Ene','Feb','Mar','Abr', 'May', 'Jun','Jul','Ago','Sep','Oct','Nov','Dic']

            year = from.year
            month = from.month
            current_year = DateTime.now.year
            product_family = ::Yito::Model::Booking::ProductFamily.get(SystemConfiguration::Variable.get_value('booking.item_family'))

            keys = []
            from_copy = from.clone
            while from_copy <= to
              keys << "#{from_copy.year}-#{months[from_copy.month-1]}-#{from_copy.day.to_s.rjust(2,'0')}"
              from_copy += 1
            end

            # Get products stocks
            conditions = category.nil? ? {} : {code: category}
            categories = ::Yito::Model::Booking::BookingCategory.all(conditions: conditions.merge({active: true}), fields: [:code, :stock])
            stocks = categories.inject({}) do |result, item|
              result.store(item.code, item.stock)
              result
            end

            # Build products occupation
            cat_occupation = categories.map{|item| item.code}.inject({}) do |result, item|
              days_hash = {}
              keys.each do |data_key|
                days_hash.store(data_key, occupied: 0, total: stocks[item])
              end
              result.store(item, days_hash)
              result
            end

            # Query bookings for the period
            query = occupation_query(from, to)

            reservations = repository.adapter.select(query)

            # Fill products occupation
            reservations.each do |reservation|
              date_from = reservation.date_from
              date_to = reservation.date_to
              date_from_copy = date_from.clone
              while date_from_copy <= date_to
                date_key = "#{date_from_copy.year}-#{months[date_from_copy.month-1]}-#{date_from_copy.day.to_s.rjust(2,'0')}"
                if cat_occupation.has_key?(reservation.item_id) and
                    cat_occupation[reservation.item_id].has_key?(date_key)
                  cat_occupation[reservation.item_id][date_key][:occupied] += reservation.quantity
                end
                date_from_copy += 1
              end
            end

            cat_occupation

          end

          private

          def categories_availability_by_category(rental_location_code, date_from, time_from, date_to, time_to, category=nil, ignore_urge=nil)

            hours_cadency = SystemConfiguration::Variable.get_value('booking.assignation_hours_return_pickup','2').to_i
            allow_different_category = SystemConfiguration::Variable.get_value('booking.assignation.allow_different_category', 'false').to_bool
            manage_availability_by_storage = availability_managed_by_storage

            #
            # 1. Build the required_categories : categories requested and summary about assignation, stock and availability
            #
            #    - The key is the category_code
            #    - The valus is a Hash
            #
            #        :total                           # of resource urges for this category (that has not been already assigned) [AFTER AUTO REASSIGN]
            #        :assignation_pending             List of reservations/prereservations that requires the item [AFTER AUTO REASSIGN]
            #        :original_total                  # of resource urges for this category [BEFORE AUTO REASSIGN]
            #        :original_assignation_pending    List of reservations/prereservations that requires the item [BEFORE AUTO REASSIGN]
            #        :reassign_total                  # of resource urges for this category [HAVE BEEN AUTO REASSIGNED]
            #        :reassigned_assignation_pending  List of reservations/prereservations that requires the item [HAVE BEEN AUTO REASSIGNED]
            #        :stock                           is a Hash
            #                                           - The key the is the stock item reference
            #                                           - The value is an array with the assigned (+ automatically assigned) reservations
            #
            categories_conditions = {active: true}
            categories_conditions.store(:code, category) if category and !allow_different_category # Category filter (1 - Building the list of categories)

            categories = ::Yito::Model::Booking::BookingCategory.all(conditions: categories_conditions,
                                                                     fields: [:code, :stock], order: [:code])

            required_categories = categories.inject({}) do |result, cat|
              result.store(cat.code, {category_stock: cat.stock,
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
            # 2. Build the stock detail structure : Inventory detail
            #
            booking_item_conditions = {active: true }

            if category
              booking_item_conditions.merge!({category_code: category})
            end

            if manage_availability_by_storage and 
               rental_location = ::Yito::Model::Booking::RentalLocation.get(rental_location_code) and rental_location.rental_storage
              booking_item_conditions.merge!({rental_storage_id: rental_location.rental_storage.id})
              manage_availability_by_storage = true  
            else
              manage_availability_by_storage = false  # The storage does not exist or does not distinguish stock y storage
            end

            stock_items = ::Yito::Model::Booking::BookingItem.all(:conditions => booking_item_conditions,
                                                                  :order => [:planning_order, :category_code, :reference])

            stock_detail = {}
            stock_items.each do |stock_item|
              # Register the item in the stock_detail hash
              stock_detail.store(stock_item.reference, {category: stock_item.category_code,
                                                        own_property: stock_item.own_property,
                                                        assignable: stock_item.assignable,
                                                        available: true,
                                                        real_stock: true,
                                                        detail: [],
                                                        estimation: []})
              # Register the item in the required_categories hash
              if required_categories.has_key?(stock_item.category_code)
                required_categories[stock_item.category_code][:stock].store(stock_item.reference, [])
              end
            end

            # 2.b Adjust stock information
            if manage_availability_by_storage
              # The category stock depends on created items not on the stock attribute
              required_categories.each do |category_code, category_value|
                category_value[:category_stock] = category_value[:stock].keys.size  
              end 
            else  
              # Create dummy resources (when category stock does not match real stock items)
              required_categories.each do |category_code, category_value|
                if category_value[:category_stock] > category_value[:stock].size
                  ((category_value[:stock].size+1)..category_value[:category_stock]).each do |idx|
                    stock_id = "DUMMY-#{category_code}-#{idx}"
                    # Add dummy resource to the category stock detail
                    category_value[:stock].store(stock_id, [])
                    # Add dummy resource to the stock detail
                    stock_detail.store(stock_id, {category: category_code,
                                                  own_property: true,
                                                  assignable: true,
                                                  available: true,
                                                  real_stock: false,
                                                  detail: [],
                                                  estimation: []})
                  end
                end
              end
            end

            #
            # 3. Fill with reservations urges : Both stock_detail and required_categories
            #
            # Get the resources urges, that is, the reservations that must be served in the period, and that are
            # not selected to be ignored (ignore_urge)
            #
            # If the urge has an assigned resource:
            #   register that the resource is not available
            #
            # If the urge has not an assigned resource:
            #   Hold in the assignation pending items
            #

            # Prepare date_from and date_to to search urges
            #
            #  - If time_from is before 02:00 am retrieve day before
            #  - If time_to is after 22:00 retrieve the next day
            #
            urge_query_date_from = date_from
            urge_query_date_to = date_to

            if time_from.split(':').first.to_i <= 2
              if date_from.is_a?Date or date_from.is_a?DateTime
                urge_query_date_from = date_from - 1
              else
                urge_query_date_from = Date.parse(date_from) - 1
              end
            end

            if time_to.split(':').first.to_i >= 22
              if date_to.is_a?Date or date_to.is_a?DateTime
                urge_query_date_to = date_to + 1
              else
                urge_query_date_to = Date.parse(date_to) + 1
              end
            end

            resource_urges_opts = {include_future_pending_confirmation: true}
            if category and !allow_different_category # Category filter (2 - Building the list of categories)
              resource_urges_opts.store(:mode, :product)
              resource_urges_opts.store(:product, category)
            end

            # Search from the previous day to the next day of the requested reservations to manage hours of difference
            resource_urges = resource_urges(urge_query_date_from, urge_query_date_to, resource_urges_opts)

            # Build requested date in a DateTime instance for comparing
            date_time_from = parse_date_time_from(date_from, time_from)
            date_time_to = parse_date_time_to(date_to, time_to)

            resource_urges.each do |resource_urge|

              # Appends a property to hold the preassigned_item_reference (during the pre-assignation process)
              resource_urge.instance_eval { class << self; self end }.send(:attr_accessor, :preassigned_item_reference)

              # Ignore urge (that corresponds to a reservation or stock-blocking)
              if (!ignore_urge.nil? and ignore_urge.is_a?(Hash) and
                  ignore_urge.has_key?(:origin) and ignore_urge.has_key?(:id) and
                  ignore_urge[:origin] == resource_urge.origin and
                  ignore_urge[:id] == resource_urge.id)
                p "categories_availability. Ignored urge by params : #{ignore_urge.inspect}"
              else
                urge_date_time_from = parse_date_time_from(resource_urge.date_from, resource_urge.time_from)
                urge_date_time_to = parse_date_time_to(resource_urge.date_to, resource_urge.time_to)
                # Ignore urge depending on the hours of difference between the search dates and the urge dates
                # - If the urge ends <hours of cadency> before the search date time from, the urge does not affect resource availability
                # - If the urge starts <hours of cadency> after the search date time to, the urge does not affect resource availability
                if urge_date_time_to < (date_time_from - Rational(hours_cadency,24)) or
                   urge_date_time_from > (date_time_to + Rational(hours_cadency,24))
                  p "categories_availability. Ignore urge by dates: #{resource_urge.id} [ #{urge_date_time_from} - #{urge_date_time_to} vs #{(date_time_from - Rational(hours_cadency,24))} - #{(date_time_to + Rational(hours_cadency,24))} ]"
                else
                  # The urge has an assigned stock resource
                  if resource_urge.booking_item_reference
                    if stock_detail.has_key?(resource_urge.booking_item_reference)
                      stock_detail[resource_urge.booking_item_reference][:available] = false
                      stock_detail[resource_urge.booking_item_reference][:detail] << resource_urge
                      # Append the resource_urge (of the assigned stock) to the category to manage the already assigned resources
                      if required_categories[resource_urge.item_id][:stock].has_key?(resource_urge.booking_item_reference)
                        required_categories[resource_urge.item_id][:stock][resource_urge.booking_item_reference] << resource_urge
                      else
                        required_categories[resource_urge.item_id][:stock][resource_urge.booking_item_reference] = [resource_urge]
                      end
                    end
                  # The urge does not have an assigned stock resource
                  else
                    if required_categories.has_key?(resource_urge.item_id)
                      required_categories[resource_urge.item_id][:total] += 1
                      required_categories[resource_urge.item_id][:assignation_pending] << resource_urge
                    end
                  end
                end

              end

            end

            #
            # 4. Try to automatically assign stock to assignation pending resource_urges
            #
            automatic_management_pending_reservations = SystemConfiguration::Variable.get_value('booking.assignation.automatically_manage_pending_of_confirmation', 'true').to_bool

            required_categories.each do |required_category_key, required_category_value|

              required_categories[required_category_key][:original_total] = required_categories[required_category_key][:total]
              required_categories[required_category_key][:original_assignation_pending] = required_categories[required_category_key][:assignation_pending].clone

              # Clones the assignation pending resource urges (because we are going to manipulate it)
              assignation_pending_sources = required_category_value[:assignation_pending].clone
              p "categories_availability. Checking assignation_pending. Category=#{required_category_key}. Total pending:#{assignation_pending_sources.size}"

              assignation_pending_sources.sort {|x,y| x.confirmed <=> y.confirmed}.each_with_index do |assignation_pending_source, index|

                p "categories_availability. Assignation pending source #{assignation_pending_source}"

                # Avoid pending of confirmation reservations if the system does not manages automatically
                next if !automatic_management_pending_reservations and assignation_pending_source.confirmed == 0

                p "categories_availability. assignation_pending_source(#{index}):#{assignation_pending_source.inspect}"
                # Build date from and date to
                pending_date_from = parse_date_time_from(assignation_pending_source.date_from,
                                                         assignation_pending_source.time_from)
                pending_date_to = parse_date_time_to(assignation_pending_source.date_to,
                                                     assignation_pending_source.time_to)
                # Search for candidates (from the category's stock)
                candidates = required_category_value[:stock].select do |item_reference, item_reference_assigned_reservations|
                  if stock_detail[item_reference][:assignable]
                    not_overlapped = item_reference_assigned_reservations.all? do |item_reference_assigned_reservation|
                      assigned_date_from = parse_date_time_from(item_reference_assigned_reservation.date_from,
                                                                item_reference_assigned_reservation.time_from)
                      assigned_date_to = parse_date_time_from(item_reference_assigned_reservation.date_to,
                                                              item_reference_assigned_reservation.time_to)
                      pending_date_to < (assigned_date_from - Rational(hours_cadency,24)) ||
                          pending_date_from > (assigned_date_to + Rational(hours_cadency,24))
                    end
                    if not_overlapped
                      free_assignations=resource_urges(assignation_pending_source.date_from,
                                                       assignation_pending_source.date_to,
                                                       {mode: :stock, reference: item_reference}).all? do |element|
                        element_date_from = parse_date_time_from(element.date_from, element.time_from)
                        element_date_to = parse_date_time_from(element.date_to, element.time_to)
                        pending_date_to < (element_date_from - Rational(hours_cadency,24)) ||
                            pending_date_from > (element_date_to + Rational(hours_cadency,24))
                      end
                      p "categories_availability. Checked(#{index}). Reference:#{item_reference}. possible=#{free_assignations}-from:#{pending_date_from}--to:#{pending_date_to}"
                      free_assignations
                    else
                      false # Reservations in requested date range overlapped
                    end
                  else
                    false # Resource is not assignable
                  end
                end
                # Candidates found => pre-assignation
                if candidates.size > 0
                  candidate_item_reference = candidates.keys.first
                  # Apply reassignation
                  required_category_value[:total] -= 1
                  required_category_value[:assignation_pending].delete(assignation_pending_source)
                  # Holds for history
                  required_category_value[:reassigned_total] += 1
                  required_category_value[:reassigned_assignation_pending] << assignation_pending_source
                  # Append the assignation pending to the stock assigned
                  required_category_value[:stock][candidate_item_reference] << assignation_pending_source
                  required_category_value[:stock][candidate_item_reference].sort! {|x,y| x.date_from <=> y.date_from }
                  if stock_detail.has_key?(candidate_item_reference)
                    stock_detail[candidate_item_reference][:estimation] << assignation_pending_source
                  end
                  assignation_pending_source.preassigned_item_reference = candidate_item_reference
                  p "categories_availability. Preassigned #{assignation_pending_source.id}-#{assignation_pending_source.id2} #{candidate_item_reference}"
                else
                  p "categories_availability. Impossible to preassign #{assignation_pending_source.id}-#{assignation_pending_source.id2}"
                end

              end

            end

            #
            # 5. Build category_occupation from required_categories and stock_detail
            #
            category_occupation = {}

            request_date_from =parse_date_time_from(date_from)
            request_date_to = parse_date_time_to(date_to)

            required_categories.each do |required_category_key, required_category_value|

              stock = required_category_value[:category_stock]
              occupation = (stock_detail.select {|k,v| v[:category] == required_category_key && (!v[:detail].empty? || !v[:estimation].empty?) }).keys.count
              occupation_assigned = (stock_detail.select {|k,v| v[:category] == required_category_key && !v[:detail].empty? }).keys.count
              available_stock = (stock_detail.select {|k,v| v[:category] == required_category_key && v[:real_stock] && v[:detail].empty? && v[:estimation].empty?}).keys
              available_assignable_stock =  (stock_detail.select {|k,v| v[:category] == required_category_key && v[:real_stock] && v[:assignable] && v[:detail].empty? && v[:estimation].empty?}).keys
              automatically_preassigned_stock = (stock_detail.select {|k,v| v[:category] == required_category_key && !v[:estimation].empty? }).keys
              available_assignable_resource = (stock_detail.select do
              |k,v| v[:category] == required_category_key && v[:detail].empty? && v[:estimation].empty? && stock_detail[k][:assignable]
              end).keys.count
              # If there is not stock, check if there are available assignable resources in order to admit reservations
              stock = occupation + available_assignable_resource if (stock <= occupation)

              category_occupation.store(required_category_key,
                                        {stock: stock, # Number that represents category total stock (take into account available assignable resources)
                                         occupation: occupation, # Number that represents the category total occupation
                                         occupation_assigned: occupation_assigned, # Number that represents the category occupation that have been assigned
                                         available_stock: available_stock, # Array of available stock item references
                                         available_assignable_stock: available_assignable_stock, # Array of available and assignable stock item references
                                         automatically_preassigned_stock: automatically_preassigned_stock, # Array of automatically pre-assigned stock item references
                                         assignation_pending: required_category_value[:original_assignation_pending],
                                         pending_confirmation_assignation_pending: required_category_value[:original_assignation_pending].select { |item| item.confirmed == 0},
                                         confirmed_assignation_pending: required_category_value[:original_assignation_pending].select { |item| item.confirmed == 1},
                                         pending_confirmation_assignation_pending_after_preassign: required_category_value[:assignation_pending].select { |item| item.confirmed == 0 },
                                         confirmed_assignation_pending_after_preassign: required_category_value[:assignation_pending].select { |item| item.confirmed == 1 },
                                         pending_confirmation_reassigned: required_category_value[:reassigned_assignation_pending].select {|item| item.confirmed == 0},
                                         confirmed_reassigned: required_category_value[:reassigned_assignation_pending].select {|item| item.confirmed == 1} })

            end

            #p "================================================================================="
            #p "stock_detail : #{stock_detail.inspect}"
            #p "required_categories: #{required_categories.inspect}"
            #p "category_occupation : #{category_occupation.inspect}"
            #p "================================================================================="

            return [stock_detail, category_occupation]
          end
          
          #
          # Categories by resource
          #
          def categories_availability_by_resource(rental_location_code, date_from, time_from, date_to, time_to, category=nil, ignore_urge=nil)

            hours_cadency = SystemConfiguration::Variable.get_value('booking.assignation_hours_return_pickup','2').to_i
            allow_different_category = SystemConfiguration::Variable.get_value('booking.assignation.allow_different_category', 'false').to_bool
            manage_availability_by_storage = availability_managed_by_storage

            #
            # 1. Build the required_categories : categories requested and summary about assignation, stock and availability
            #
            #    - The key is the category_code
            #    - The valus is a Hash
            #
            #        :total                           # of resource urges for this category (that has not been already assigned) [AFTER AUTO REASSIGN]
            #        :assignation_pending             List of reservations/prereservations that requires the item [AFTER AUTO REASSIGN]
            #        :original_total                  # of resource urges for this category [BEFORE AUTO REASSIGN]
            #        :original_assignation_pending    List of reservations/prereservations that requires the item [BEFORE AUTO REASSIGN]
            #        :reassign_total                  # of resource urges for this category [HAVE BEEN AUTO REASSIGNED]
            #        :reassigned_assignation_pending  List of reservations/prereservations that requires the item [HAVE BEEN AUTO REASSIGNED]
            #        :stock                           is a Hash
            #                                           - The key the is the stock item reference
            #                                           - The value is an array with the assigned (+ automatically assigned) reservations
            #            
            required_categories = {}
            stock_detail = {}

            if manage_availability_by_storage and 
               rental_location = ::Yito::Model::Booking::RentalLocation.get(rental_location_code) and rental_location.rental_storage
                ::Yito::Model::Booking::BookingItem.all(conditions: {own_property: true, active: true, assignable: true,
                                                                     rental_storage_id: rental_location.rental_storage.id },
                                                        fields: [:reference], order: [:planning_order, :category_code, :reference]).each do |booking_item|
                required_categories.store(booking_item.reference, 
                             {category_stock: 1,
                              total: 0,
                              assignation_pending: [],
                              original_total: 0,
                              original_assignation_pending: [],
                              reassigned_total: 0,
                              reassigned_assignation_pending: [],
                              stock: { booking_item.reference => [] }
                              })
                stock_detail.store(booking_item.reference, {category: booking_item.reference,
                                                            own_property: booking_item.own_property,
                                                            assignable: booking_item.assignable,
                                                            available: true,
                                                            real_stock: true,
                                                            detail: [],
                                                            estimation: []})
              end              
            else
              ::Yito::Model::Booking::BookingItem.all(conditions: {own_property: true, active: true, assignable: true},
                                                      fields: [:reference, :own_property, :assignable], order: [:planning_order, :category_code, :reference]).each do |booking_item|
                required_categories.store(booking_item.reference, 
                             {category_stock: 1,
                              total: 0,
                              assignation_pending: [],
                              original_total: 0,
                              original_assignation_pending: [],
                              reassigned_total: 0,
                              reassigned_assignation_pending: [],
                              stock: { booking_item.reference => [] }
                              })
                stock_detail.store(booking_item.reference, {category: booking_item.reference,
                                                        own_property: booking_item.own_property,
                                                        assignable: booking_item.assignable,
                                                        available: true,
                                                        real_stock: true,
                                                        detail: [],
                                                        estimation: []})                
                                    
              end
            end  

            #
            # 2. Fill with reservations urges : Both stock_detail and required_categories
            #
            # Get the resources urges, that is, the reservations that must be served in the period, and that are
            # not selected to be ignored (ignore_urge)
            #
            # If the urge has an assigned resource:
            #   register that the resource is not available
            #
            # If the urge has not an assigned resource:
            #   Hold in the assignation pending items
            #

            # Prepare date_from and date_to to search urges
            #
            #  - If time_from is before 02:00 am retrieve day before
            #  - If time_to is after 22:00 retrieve the next day
            #
            urge_query_date_from = date_from
            urge_query_date_to = date_to

            if time_from.split(':').first.to_i <= 2
              if date_from.is_a?Date or date_from.is_a?DateTime
                urge_query_date_from = date_from - 1
              else
                urge_query_date_from = Date.parse(date_from) - 1
              end
            end

            if time_to.split(':').first.to_i >= 22
              if date_to.is_a?Date or date_to.is_a?DateTime
                urge_query_date_to = date_to + 1
              else
                urge_query_date_to = Date.parse(date_to) + 1
              end
            end

            resource_urges_opts = {include_future_pending_confirmation: true}
            if category and !allow_different_category # Category filter (2 - Building the list of categories)
              resource_urges_opts.store(:mode, :product)
              resource_urges_opts.store(:product, category)
            end

            # Search from the previous day to the next day of the requested reservations to manage hours of difference
            resource_urges = resource_urges(urge_query_date_from, urge_query_date_to, resource_urges_opts)

            # Build requested date in a DateTime instance for comparing
            date_time_from = parse_date_time_from(date_from, time_from)
            date_time_to = parse_date_time_to(date_to, time_to)

            resource_urges.each do |resource_urge|

              # Appends a property to hold the preassigned_item_reference (during the pre-assignation process)
              resource_urge.instance_eval { class << self; self end }.send(:attr_accessor, :preassigned_item_reference)

              # Ignore urge (that corresponds to a reservation or stock-blocking)
              if (!ignore_urge.nil? and ignore_urge.is_a?(Hash) and
                  ignore_urge.has_key?(:origin) and ignore_urge.has_key?(:id) and
                  ignore_urge[:origin] == resource_urge.origin and
                  ignore_urge[:id] == resource_urge.id)
                p "categories_availability. Ignored urge by params : #{ignore_urge.inspect}"
              else
                urge_date_time_from = parse_date_time_from(resource_urge.date_from, resource_urge.time_from)
                urge_date_time_to = parse_date_time_to(resource_urge.date_to, resource_urge.time_to)
                # Ignore urge depending on the hours of difference between the search dates and the urge dates
                # - If the urge ends <hours of cadency> before the search date time from, the urge does not affect resource availability
                # - If the urge starts <hours of cadency> after the search date time to, the urge does not affect resource availability
                if urge_date_time_to < (date_time_from - Rational(hours_cadency,24)) or
                   urge_date_time_from > (date_time_to + Rational(hours_cadency,24))
                  p "categories_availability. Ignore urge by dates: #{resource_urge.id} [ #{urge_date_time_from} - #{urge_date_time_to} vs #{(date_time_from - Rational(hours_cadency,24))} - #{(date_time_to + Rational(hours_cadency,24))} ]"
                else
                  # The urge has an assigned stock resource
                  if resource_urge.booking_item_reference
                    if stock_detail.has_key?(resource_urge.booking_item_reference)
                      stock_detail[resource_urge.booking_item_reference][:available] = false
                      stock_detail[resource_urge.booking_item_reference][:detail] << resource_urge
                      # Append the resource_urge (of the assigned stock) to the category to manage the already assigned resources
                      if required_categories[resource_urge.item_id][:stock].has_key?(resource_urge.booking_item_reference)
                        required_categories[resource_urge.item_id][:stock][resource_urge.booking_item_reference] << resource_urge
                      else
                        required_categories[resource_urge.item_id][:stock][resource_urge.booking_item_reference] = [resource_urge]
                      end
                    end
                  # The urge does not have an assigned stock resource
                  else
                    if required_categories.has_key?(resource_urge.item_id)
                      required_categories[resource_urge.item_id][:total] += 1
                      required_categories[resource_urge.item_id][:assignation_pending] << resource_urge
                    end
                  end
                end

              end

            end

            #
            # 3. Try to automatically assign stock to assignation pending resource_urges
            #
            automatic_management_pending_reservations = SystemConfiguration::Variable.get_value('booking.assignation.automatically_manage_pending_of_confirmation', 'true').to_bool

            required_categories.each do |required_category_key, required_category_value|

              required_categories[required_category_key][:original_total] = required_categories[required_category_key][:total]
              required_categories[required_category_key][:original_assignation_pending] = required_categories[required_category_key][:assignation_pending].clone

              # Clones the assignation pending resource urges (because we are going to manipulate it)
              assignation_pending_sources = required_category_value[:assignation_pending].clone
              p "categories_availability. Checking assignation_pending. Category=#{required_category_key}. Total pending:#{assignation_pending_sources.size}"

              assignation_pending_sources.sort {|x,y| x.confirmed <=> y.confirmed}.each_with_index do |assignation_pending_source, index|

                p "categories_availability. Assignation pending source #{assignation_pending_source}"

                # Avoid pending of confirmation reservations if the system does not manages automatically
                next if !automatic_management_pending_reservations and assignation_pending_source.confirmed == 0

                p "categories_availability. assignation_pending_source(#{index}):#{assignation_pending_source.inspect}"
                # Build date from and date to
                pending_date_from = parse_date_time_from(assignation_pending_source.date_from,
                                                         assignation_pending_source.time_from)
                pending_date_to = parse_date_time_to(assignation_pending_source.date_to,
                                                     assignation_pending_source.time_to)
                # Search for candidates (from the category's stock)
                candidates = required_category_value[:stock].select do |item_reference, item_reference_assigned_reservations|
                  if stock_detail[item_reference][:assignable]
                    not_overlapped = item_reference_assigned_reservations.all? do |item_reference_assigned_reservation|
                      assigned_date_from = parse_date_time_from(item_reference_assigned_reservation.date_from,
                                                                item_reference_assigned_reservation.time_from)
                      assigned_date_to = parse_date_time_from(item_reference_assigned_reservation.date_to,
                                                              item_reference_assigned_reservation.time_to)
                      pending_date_to < (assigned_date_from - Rational(hours_cadency,24)) ||
                          pending_date_from > (assigned_date_to + Rational(hours_cadency,24))
                    end
                    if not_overlapped
                      free_assignations=resource_urges(assignation_pending_source.date_from,
                                                       assignation_pending_source.date_to,
                                                       {mode: :stock, reference: item_reference}).all? do |element|
                        element_date_from = parse_date_time_from(element.date_from, element.time_from)
                        element_date_to = parse_date_time_from(element.date_to, element.time_to)
                        pending_date_to < (element_date_from - Rational(hours_cadency,24)) ||
                            pending_date_from > (element_date_to + Rational(hours_cadency,24))
                      end
                      p "categories_availability. Checked(#{index}). Reference:#{item_reference}. possible=#{free_assignations}-from:#{pending_date_from}--to:#{pending_date_to}"
                      free_assignations
                    else
                      false # Reservations in requested date range overlapped
                    end
                  else
                    false # Resource is not assignable
                  end
                end
                # Candidates found => pre-assignation
                if candidates.size > 0
                  candidate_item_reference = candidates.keys.first
                  # Apply reassignation
                  required_category_value[:total] -= 1
                  required_category_value[:assignation_pending].delete(assignation_pending_source)
                  # Holds for history
                  required_category_value[:reassigned_total] += 1
                  required_category_value[:reassigned_assignation_pending] << assignation_pending_source
                  # Append the assignation pending to the stock assigned
                  required_category_value[:stock][candidate_item_reference] << assignation_pending_source
                  required_category_value[:stock][candidate_item_reference].sort! {|x,y| x.date_from <=> y.date_from }
                  if stock_detail.has_key?(candidate_item_reference)
                    stock_detail[candidate_item_reference][:estimation] << assignation_pending_source
                  end
                  assignation_pending_source.preassigned_item_reference = candidate_item_reference
                  p "categories_availability. Preassigned #{assignation_pending_source.id}-#{assignation_pending_source.id2} #{candidate_item_reference}"
                else
                  p "categories_availability. Impossible to preassign #{assignation_pending_source.id}-#{assignation_pending_source.id2}"
                end

              end

            end

            #
            # 4. Build category_occupation from required_categories and stock_detail
            #
            category_occupation = {}

            request_date_from =parse_date_time_from(date_from)
            request_date_to = parse_date_time_to(date_to)

            required_categories.each do |required_category_key, required_category_value|

              stock = required_category_value[:category_stock]
              occupation = (stock_detail.select {|k,v| v[:category] == required_category_key && (!v[:detail].empty? || !v[:estimation].empty?) }).keys.count
              occupation_assigned = (stock_detail.select {|k,v| v[:category] == required_category_key && !v[:detail].empty? }).keys.count
              available_stock = (stock_detail.select {|k,v| v[:category] == required_category_key && v[:real_stock] && v[:detail].empty? && v[:estimation].empty?}).keys
              available_assignable_stock =  (stock_detail.select {|k,v| v[:category] == required_category_key && v[:real_stock] && v[:assignable] && v[:detail].empty? && v[:estimation].empty?}).keys
              automatically_preassigned_stock = (stock_detail.select {|k,v| v[:category] == required_category_key && !v[:estimation].empty? }).keys
              available_assignable_resource = (stock_detail.select do
              |k,v| v[:category] == required_category_key && v[:detail].empty? && v[:estimation].empty? && stock_detail[k][:assignable]
              end).keys.count
              # If there is not stock, check if there are available assignable resources in order to admit reservations
              stock = occupation + available_assignable_resource if (stock <= occupation)

              category_occupation.store(required_category_key,
                                        {stock: stock, # Number that represents category total stock (take into account available assignable resources)
                                         occupation: occupation, # Number that represents the category total occupation
                                         occupation_assigned: occupation_assigned, # Number that represents the category occupation that have been assigned
                                         available_stock: available_stock, # Array of available stock item references
                                         available_assignable_stock: available_assignable_stock, # Array of available and assignable stock item references
                                         automatically_preassigned_stock: automatically_preassigned_stock, # Array of automatically pre-assigned stock item references
                                         assignation_pending: required_category_value[:original_assignation_pending],
                                         pending_confirmation_assignation_pending: required_category_value[:original_assignation_pending].select { |item| item.confirmed == 0},
                                         confirmed_assignation_pending: required_category_value[:original_assignation_pending].select { |item| item.confirmed == 1},
                                         pending_confirmation_assignation_pending_after_preassign: required_category_value[:assignation_pending].select { |item| item.confirmed == 0 },
                                         confirmed_assignation_pending_after_preassign: required_category_value[:assignation_pending].select { |item| item.confirmed == 1 },
                                         pending_confirmation_reassigned: required_category_value[:reassigned_assignation_pending].select {|item| item.confirmed == 0},
                                         confirmed_reassigned: required_category_value[:reassigned_assignation_pending].select {|item| item.confirmed == 1} })

            end

            #p "================================================================================="
            #p "stock_detail : #{stock_detail.inspect}"
            #p "required_categories: #{required_categories.inspect}"
            #p "category_occupation : #{category_occupation.inspect}"
            #p "================================================================================="

            return [stock_detail, category_occupation]
          end  

          #
          # Get the occupation query SQL
          #
          def occupation_query(from, to)

            query = <<-QUERY
                SELECT coalesce(lr.booking_item_category, l.item_id) as item_id, 
                       b.id, 
                       b.date_from as date_from,
                       b.date_to as date_to,
                       b.days as days,
                       lr.booking_item_reference, 
                       1 as quantity 
                FROM bookds_bookings_lines as l
                JOIN bookds_bookings as b on b.id = l.booking_id
                JOIN bookds_bookings_lines_resources as lr on lr.booking_line_id = l.id
                WHERE ((b.date_from <= '#{from}' and b.date_to >= '#{from}') or 
                   (b.date_from <= '#{to}' and b.date_to >= '#{to}') or 
                   (b.date_from = '#{from}' and b.date_to = '#{to}') or
                   (b.date_from >= '#{from}' and b.date_to <= '#{to}')) and
                   b.status NOT IN (1,5)
                UNION
                SELECT prl.booking_item_category as item_id,
                       pr.id,
                       pr.date_from as date_from,
                       pr.date_to as date_to,
                       pr.days as days,
                       prl.booking_item_reference,
                       1 as quantity
                FROM bookds_prereservations pr
                JOIN bookds_prereservation_lines prl on prl.prereservation_id = pr.id
                WHERE ((pr.date_from <= '#{from}' and pr.date_to >= '#{from}') or 
                   (pr.date_from <= '#{to}' and pr.date_to >= '#{to}') or 
                   (pr.date_from = '#{from}' and pr.date_to = '#{to}') or
                   (pr.date_from >= '#{from}' and pr.date_to <= '#{to}'))
                ORDER BY item_id, date_from
            QUERY

          end

        end

      end
    end
  end
end