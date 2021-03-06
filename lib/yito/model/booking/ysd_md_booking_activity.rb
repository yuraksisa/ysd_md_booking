require 'set' unless defined?Set
module Yito
  module Model
    module Booking
      #
      # It represents an activity
      #
      class Activity
        include DataMapper::Resource
        extend  Plugins::ApplicableModelAspect          
        extend  Yito::Model::Finder
        include Yito::Model::Booking::BookingActivityTranslation
        
        storage_names[:default] = 'bookds_activities'
        
        # -- Basic attributes

        property :id, Serial
        property :code, String, :length => 50      
        property :name, String, :length => 80
        property :short_description, String, :length => 256
        property :title, String, length: 100
        property :subtitle, Text
        property :description, Text
        property :detailed_info_what_includes, Text
        property :detailed_info_timetable_duration, Text
        property :detailed_info_ages, Text
        property :detailed_info_recommendations, Text
        property :detailed_info_meeting_point, Text
        property :is_highlighted, Boolean, default: false
        property :occurence, Enum[:one_time, :multiple_dates, :cyclic]
        property :mode, Enum[:full,:partial], :default => :full
        property :active, Boolean, :default => true
        property :web_public, Boolean, :default => true
        property :alias, String, :length => 80
        
        property :request_customer_information, Boolean, :default => false
        property :request_customer_address, Boolean, :default => false
        property :request_customer_document_id, Boolean, :default => false
        property :request_customer_phone, Boolean, :default => false
        property :request_customer_email, Boolean, :default => false
        property :request_customer_height, Boolean, :default => false
        property :request_customer_weight, Boolean, :default => false
        property :request_customer_allergies_intolerances, Boolean, :default => false
        property :uses_planning_resources, Boolean, :default => false

        # -- Own contract
        property :own_contract, Boolean, :default => false
        belongs_to :contract, '::ContentManagerSystem::Template', child_key: [:contract_id], parent_key: [:id], :required => false

        property :from_price, Decimal, :scale => 2, :precision => 10, :default => 0
        property :from_price_offer, Decimal, :scale => 2, :precision => 10, :default => 0 

        property :schedule_color, String, :length => 9
        property :duration_days, Integer, :default => 0
        property :duration_hours, String, :length => 5

        # -- Custom payments
        property :custom_payment_allow_deposit_payment, Boolean, default: false
        property :custom_payment_deposit, Integer, default: 0
        property :custom_payment_allow_total_payment, Boolean, default: false

        # -- Allows to request a reservation (without payment)
        property :allow_request_reservation, Boolean, default: false

        # -- Pickup places
        property :custom_pickup_places, Boolean, default: false
        belongs_to :pickup_return_place_definition, 'Yito::Model::Booking::PickupReturnPlaceDefinition', :required => false

        # -- One time 

        property :date_from, DateTime
        property :time_from, String, :length => 5
        property :date_to, DateTime
        property :time_to, String, :length => 5 

        # -- Multiple dates activities

        has n, :activity_dates, 'ActivityDate', :constraint => :destroy, :order => [:date_from.desc]

        # -- Cyclic activities

        belongs_to :calendar, 'Yito::Model::Calendar::Calendar', :required => false
        
        # To manage if the activity is offered all year or only on specific period
        property :all_year, Boolean, :default => true
        property :from_day, Integer
        property :from_month, Integer
        property :to_day, Integer
        property :to_month, Integer

        # Days when the activity is performed
        property :all_days, Boolean, :default => true
        property :sundays, Boolean, :default => false
        property :mondays, Boolean, :default => false
        property :tuesdays, Boolean, :default => false
        property :wednesdays, Boolean, :default => false
        property :thursdays, Boolean, :default => false
        property :fridays, Boolean, :default => false
        property :saturdays, Boolean, :default => false

        # Turns
        property :all_days_same_turns, Boolean, :default => true
        property :morning_turns, String, :length => 255
        property :afternoon_turns, String, :length => 255
        property :night_turns, String, :length => 255
        property :sunday_morning_turns, String, :length => 255
        property :sunday_afternoon_turns, String, :length => 255
        property :sunday_night_turns, String, :length => 255
        property :monday_morning_turns, String, :length => 255
        property :monday_afternoon_turns, String, :length => 255
        property :monday_night_turns, String, :length => 255
        property :tuesday_morning_turns, String, :length => 255
        property :tuesday_afternoon_turns, String, :length => 255
        property :tuesday_night_turns, String, :length => 255
        property :wednesday_morning_turns, String, :length => 255
        property :wednesday_afternoon_turns, String, :length => 255
        property :wednesday_night_turns, String, :length => 255
        property :thursday_morning_turns, String, :length => 255
        property :thursday_afternoon_turns, String, :length => 255
        property :thursday_night_turns, String, :length => 255                   
        property :friday_morning_turns, String, :length => 255
        property :friday_afternoon_turns, String, :length => 255
        property :friday_night_turns, String, :length => 255
        property :saturday_morning_turns, String, :length => 255
        property :saturday_afternoon_turns, String, :length => 255
        property :saturday_night_turns, String, :length => 255

        property :notify_customer_if_empty, Boolean, :default => false

        # -- Other attributes

        property :capacity, Integer, :default => 0

        # -- Prices
        property :type_of_multiple_prices, Enum[:none, :duration, :ages, :accomodation], default: :none
        property :capacities_on_multiple_prices, Boolean, :default => false

        property :price_1_description, String, :length => 255
        property :price_1_total_capacity, Integer, :default => 0
        property :price_1_affects_capacity, Boolean, :default => true
        property :price_1_duration_days, Integer, :default => 0
        property :price_1_duration_hours, String, :length => 5
        property :price_1_step_tickets, Integer, :default => 1
        belongs_to :price_definition_1, 'Yito::Model::Rates::PriceDefinition', :required => false
        
        property :price_2_description, String, :length => 255
        property :price_2_total_capacity, Integer, :default => 0
        property :price_2_affects_capacity, Boolean, :default => false
        property :price_2_duration_days, Integer, :default => 0
        property :price_2_duration_hours, String, :length => 5
        property :price_2_step_tickets, Integer, :default => 1
        belongs_to :price_definition_2, 'Yito::Model::Rates::PriceDefinition', :required => false
        
        property :price_3_description, String, :length => 255
        property :price_3_total_capacity, Integer, :default => 0
        property :price_3_affects_capacity, Boolean, :default => false
        property :price_3_duration_days, Integer, :default => 0
        property :price_3_duration_hours, String, :length => 5
        property :price_3_step_tickets, Integer, :default => 1
        belongs_to :price_definition_3, 'Yito::Model::Rates::PriceDefinition', :required => false

        # Family and subfamily
        belongs_to :family, '::Yito::Model::Classifier::ClassifierTerm', child_key: [:family_id], parent_key: [:id], required: false
        belongs_to :sub_family, '::Yito::Model::Classifier::ClassifierTerm', child_key: [:subfamily_id], parent_key: [:id], required: false

        # Tags (classifiers)
        has n, :activity_classifier_terms, 'ActivityClassifierTerm', :child_key => [:activity_id], :parent_key => [:id], :constraint => :destroy
        has n, :classifier_terms, '::Yito::Model::Classifier::ClassifierTerm', :through => :activity_classifier_terms, :via => :classifier_term

        # Supplier
        belongs_to :supplier, 'Yito::Model::Suppliers::Supplier', child_key: [:supplier_id], parent_id: [:id], required: false

        # ==================================   HOOKS   ============================================================

        before :create do
          if self.alias.nil? or self.alias.empty?     
            self.alias = File.join('/', UnicodeUtils.nfkd(self.name).gsub(/[^\x00-\x7F]/,'').gsub(/\s/,'-'))[0..79]
          end
        end

        before :save do
          if self.own_contract and self.contract.nil?
            self.contract = ContentManagerSystem::Template.create(name: self.code, description: self.name)
          end
        end

        #
        # Save the activity
        #
        def save
          check_contract! if self.contract
          check_calendar! if self.calendar
          check_price_definition! if self.price_definition_1 || self.price_definition_2 || self.price_definition_3
          super # Invokes the super class to achieve the chain of methods invoked       
        end

        #
        # Get the prices total capacity
        #
        def prices_total_capacity
          t = 0
          t += price_1_total_capacity if !price_definition_1.nil? and price_1_affects_capacity and !price_1_total_capacity.nil?
          t += price_2_total_capacity if !price_definition_2.nil? and price_2_affects_capacity and !price_2_total_capacity.nil?
          t += price_3_total_capacity if !price_definition_3.nil? and price_3_affects_capacity and !price_3_total_capacity.nil?
          return t
        end

        #
        # Get the date for one time timetable
        #
        def one_time_timetable
          if occurence == :one_time
            [time_from]
          else
            nil
          end
        end

        #
        # Get the "turns" for multiple date timetable
        #
        def multiple_dates_timetable
          if occurence == :multiple_dates
            (self.activity_dates.map { |activity_date| activity_date.time_from.empty? ? activity_date.time_from : activity_date.time_from.rjust(5,"0") }).select { |time| !time.empty? }.uniq.sort
          else
            nil
          end
        end

        #
        # Get the turns summary (taking into account all days)
        #
        def cyclic_turns_summary
          result = Set.new
          if all_days_same_turns
            process_turns([morning_turns,afternoon_turns,night_turns], result)
          else
            process_turns([sunday_morning_turns,sunday_afternoon_turns,sunday_night_turns,
                           monday_morning_turns,monday_afternoon_turns,monday_night_turns,
                           tuesday_morning_turns,tuesday_afternoon_turns,tuesday_night_turns,
                           wednesday_morning_turns,wednesday_afternoon_turns,wednesday_night_turns,
                           thursday_morning_turns,thursday_afternoon_turns,thursday_night_turns,
                           friday_morning_turns,friday_afternoon_turns,friday_night_turns,
                           saturday_morning_turns,saturday_afternoon_turns,saturday_night_turns], result)
          end
          return result.to_a.sort { |x,y| Time.parse(x) <=> Time.parse(y) }
        end
        
        #
        # Check if a day has turn
        #
        def cyclic_has_turn?(day_of_week, turn)
          result = Set.new
          if all_days_same_turns
            process_turns([morning_turns,afternoon_turns,night_turns], result)
          else
            case day_of_week
              when 0 # sunday
                process_turns([sunday_morning_turns,sunday_afternoon_turns,sunday_night_turns], result)
              when 1 
                process_turns([monday_morning_turns,monday_afternoon_turns,monday_night_turns], result)
              when 2
                process_turns([tuesday_morning_turns,tuesday_afternoon_turns,tuesday_night_turns], result)
              when 3
                process_turns([wednesday_morning_turns,wednesday_afternoon_turns,wednesday_night_turns], result)
              when 4
                process_turns([thursday_morning_turns,thursday_afternoon_turns,thursday_night_turns], result)
              when 5
                process_turns([friday_morning_turns,friday_afternoon_turns,friday_night_turns], result)
              when 6
                process_turns([saturday_morning_turns,saturday_afternoon_turns,saturday_night_turns], result)
            end
          end
          result.contains?(turn)
        end
        
        #
        # Check if the activity is planned for a day of week
        #
        def cyclic_planned?(day_of_week)
          return false unless occurence == :cyclic
          return true if all_days
          case day_of_week
            when 0 
              return true if sundays
            when 1
              return true if mondays 
            when 2
              return true if tuesdays
            when 3
              return true if wednesdays 
            when 4
              return true if thursdays 
            when 5
              return true if fridays 
            when 6
              return true if saturdays
          end
          return false 
        end

        #
        # Check if a date correponds
        #
        def start_date?(date)
          if occurence == :one_time
            self.date_from.to_date == date
          elsif occurence == :multiple_dates
            (activity_dates.select { |item| item.date_from.to_date == date  }).size > 0
          else
            return false
          end
        end

        #
        # Check if an activity is alive.
        #
        def lives?

          if occurence == :multiple_dates
            today = Date.today
            (activity_dates.select { |item| item.date_from >= today  }).size > 0
          elsif occurence == :one_time
            date_from >= Date.today
          else
            true
          end

        end

        #
        # Get the number of different item price
        #
        def number_of_item_price
          number_of_prices = 0
          number_of_prices += 1 unless price_definition_1.nil?
          number_of_prices += 1 unless price_definition_2.nil?
          number_of_prices += 1 unless price_definition_3.nil?    
          return number_of_prices      
        end

        def price_definition_detail
          result = {}
          result.store(1, price_1_description) unless price_definition_1.nil?
          result.store(2, price_2_description) unless price_definition_2.nil?
          result.store(3, price_3_description) unless price_definition_3.nil?
          return result
        end

        #
        # Check if the activity has prices for different seasons 
        #
        def season_prices?
          (!price_definition_1.nil? && price_definition_1.season?) ||
          (!price_definition_2.nil? && price_definition_2.season?) ||
          (!price_definition_3.nil? && price_definition_3.season?)
        end

        #
        # Get the activity rate's detail for a date
        #
        def rates(date)
          build_rates(date)
        end
        
        #
        # Get the actitivy rate's detail
        #
        def rates_hash(date)
          rates = build_rates(date)
          result = {1 => {}, 2 => {}, 3 => {}}
          
          unless price_definition_1.nil?
            rate_1 = {} 
            rates[1].each do |quantity, price| 
              rate_1[quantity] = price
            end
            result[1] = rate_1
          end 

          unless price_definition_2.nil?
            rate_2 = {} 
            rates[2].each do |quantity, price| 
              rate_2[quantity] = price
            end
            result[2] = rate_2
          end 

          unless price_definition_3.nil?
            rate_3 = {} 
            rates[3].each do |quantity, price| 
              rate_3[quantity] = price
            end
            result[3] = rate_3
          end 

          return result

        end

        #
        # Get the tickets
        #
        def tickets(occupation_date, occupation_time, occupation_price_type=nil)

          occupation = self.occupation(occupation_date, occupation_time, occupation_price_type)
          price_definition_detail = self.price_definition_detail
          rates = self.rates_hash(occupation_date)

          result = {}
          price_definition_detail.each do |id, description|
            tickets = [{number: 0, total: 0, description: "Número de tickets (#{description})"}]
            (1..(occupation[:occupation_capacity]-(occupation[:occupation_detail][id]||0))).each do |item|
              tickets << {number:item, total:rates[id][item], description: "#{item} X #{description} #{rates[id][item]}€"}
            end
            result.store(id, tickets)
          end

          return result

        end

        # Get the occupation for a price type
        # @Return [Hash] :total_occupation holds the total occupation
        #                :occupation_detail is a Hash where key is the item_price_type and value is the occupation
        def occupation(occupation_date, occupation_time, occupation_price_type=nil)
          data = Yito::Model::Order::Order.occupation(code, 
                   occupation_date, occupation_time, occupation_price_type)
          
          total_occupation = 0
          occupation_detail = {}
          occupation_detail.store(1, 0) unless price_definition_1.nil?
          occupation_detail.store(2, 0) unless price_definition_2.nil?
          occupation_detail.store(3, 0) unless price_definition_3.nil?

          data.each do |item|
            occupation_detail[item.item_price_type] = item.occupation
            total_occupation += item.occupation
          end          
          
          # Get the planned activity
          planned_activity = ::Yito::Model::Booking::PlannedActivity.first(date: occupation_date,
                                                                           time: occupation_time,
                                                                           activity_code: self.code)
          occupation_capacity = planned_activity.nil? ? self.capacity : planned_activity.capacity

          result = {total_occupation: total_occupation.to_i, occupation_detail: occupation_detail, occupation_capacity: occupation_capacity}
        
          return result

        end

        #
        # Exporting to json
        #
        def as_json(options={})

          if options.has_key?(:only)
            super(options)
          else
            relationships = options[:relationships] || {}
            relationships.store(:activity_dates, {})
            methods = options[:methods] || []
            methods << :prices_total_capacity
            super(options.merge({:relationships => relationships, :methods => methods}))
          end

        end

        private

        def process_turns(turns_group, turns_set)
          turns_group.each do |turn_group|
            if !turn_group.nil? and !turn_group.empty?
              turn_group.split(',').each do |turn|
                turns_set.add(turn) if !turn.nil? and !turn.empty?
              end
            end
          end
        end

        #
        # Get the rates for an activity in one date
        #
        def build_rates(date)
          
          return nil unless mode == :partial

          rates_result = {}

          unless price_definition_1.nil?
            rates_result.store(1, price_definition_1.calculate_multiple_prices(date, capacity))
          end

          unless price_definition_2.nil?
            rates_result.store(2, price_definition_2.calculate_multiple_prices(date, capacity))
          end

          unless price_definition_3.nil?
            rates_result.store(3, price_definition_3.calculate_multiple_prices(date, capacity))
          end

          return rates_result

        end
        
        # ---------------------------------------------------------------

        def check_calendar!

          if self.calendar and (not self.calendar.saved?) and loaded = ::Yito::Model::Calendar::Calendar.get(self.calendar.id)
            self.calendar = loaded
          end

          if self.calendar and self.calendar.id.nil?
            self.calendar.save
          end

        end

        def check_contract!
          if self.contract and (not self.contract.saved?) and loaded = ::ContentManagerSystem::Template.get(self.contract.id)
            self.contract = loaded
          end
          if self.contract and self.contract.id.nil?
            self.contract.save
          end
        end


        def check_price_definition!
          if self.price_definition_1 and (not self.price_definition_1.saved?) and 
             loaded = ::Yito::Model::Rates::PriceDefinition.get(self.price_definition_1.id)
            self.price_definition_1 = loaded
          end
          if self.price_definition_1 and self.price_definition_1.id.nil?
            self.price_definition_1.save
          end

          if self.price_definition_2 and (not self.price_definition_2.saved?) and 
             loaded = ::Yito::Model::Rates::PriceDefinition.get(self.price_definition_2.id)
            self.price_definition_2 = loaded
          end
          if self.price_definition_2 and self.price_definition_2.id.nil?
            self.price_definition_2.save
          end

          if self.price_definition_3 and (not self.price_definition_3.saved?) and 
             loaded = ::Yito::Model::Rates::PriceDefinition.get(self.price_definition_3.id)
            self.price_definition_3 = loaded
          end
          if self.price_definition_3 and self.price_definition_3.id.nil?
            self.price_definition_3.save
          end          

        end



      end
    end
  end
end