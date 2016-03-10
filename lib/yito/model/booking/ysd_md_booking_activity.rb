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

        storage_names[:default] = 'bookds_activities'
        
        # -- Basic attributes

        property :id, Serial
        property :code, String, :length => 50      
        property :name, String, :length => 80
        property :short_description, String, :length => 256
        property :description, Text
        property :occurence, Enum[:one_time, :multiple_dates, :cyclic]
        property :mode, Enum[:full,:partial], :default => :full
        property :active, Boolean, :default => true
        property :from_price, Decimal, :scale => 2, :precision => 10, :default => 0
        property :from_price_offer, Decimal, :scale => 2, :precision => 10, :default => 0 

        # -- One time 

        property :date_from, DateTime
        property :time_from, String, :length => 5
        property :date_to, DateTime
        property :time_to, String, :length => 5 

        # -- Multiple dates activities

        has n, :activity_dates, 'ActivityDate', :constraint => :destroy

        # -- Cyclic activities

        belongs_to :calendar, 'Yito::Model::Calendar::Calendar', :required => false

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
        belongs_to :price_definition_1, 'Yito::Model::Rates::PriceDefinition', :required => false
        
        property :price_2_description, String, :length => 255
        property :price_2_total_capacity, Integer, :default => 0
        property :price_2_affects_capacity, Boolean, :default => false
        property :price_2_duration_days, Integer, :default => 0
        property :price_2_duration_hours, String, :length => 5
        belongs_to :price_definition_2, 'Yito::Model::Rates::PriceDefinition', :required => false
        
        property :price_3_description, String, :length => 255
        property :price_3_total_capacity, Integer, :default => 0
        property :price_3_affects_capacity, Boolean, :default => false
        property :price_3_duration_days, Integer, :default => 0
        property :price_3_duration_hours, String, :length => 5
        belongs_to :price_definition_3, 'Yito::Model::Rates::PriceDefinition', :required => false

        def save
          check_calendar! if self.calendar
          check_price_definition! if self.price_definition_1 || self.price_definition_2 || self.price_definition_3
          super # Invokes the super class to achieve the chain of methods invoked       
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
          case occurence
            when :cyclic 
              cyclic_rates(date)
          end
        end
        
        # Get the occupation for a price type
        #
        def occupation(occupation_date, occupation_time, occupation_price_type=nil)
          Yito::Model::Order::Order.occupation(code, 
              occupation_date, occupation_time, occupation_price_type)
        end

        private

        #
        # Get the rates for an activity in one date
        #
        def cyclic_rates(date)
          
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