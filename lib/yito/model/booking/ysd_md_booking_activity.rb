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
        property :price_1_description, String, :length => 255
        property :price_2_description, String, :length => 255
        property :price_3_description, String, :length => 255
        belongs_to :price_definition_1, 'Yito::Model::Rates::PriceDefinition', :required => false
        belongs_to :price_definition_2, 'Yito::Model::Rates::PriceDefinition', :required => false
        belongs_to :price_definition_3, 'Yito::Model::Rates::PriceDefinition', :required => false

        def save
          p "Saving activity #{self.price_definition_1 || self.price_definition_2 || self.price_definition_3}"
          p "#{self.price_definition_1.inspect}"
          check_calendar! if self.calendar
          check_price_definition! if self.price_definition_1 || self.price_definition_2 || self.price_definition_3
          super # Invokes the super class to achieve the chain of methods invoked       
        end

        private

        def check_calendar!

          if self.calendar and (not self.calendar.saved?) and loaded = ::Yito::Model::Calendar::Calendar.get(self.calendar.id)
            self.calendar = loaded
          end

          if self.calendar and self.calendar.id.nil?
            self.calendar.save
          end

        end


        def check_price_definition!
          p "checking price definition"
          if self.price_definition_1 and (not self.price_definition_1.saved?) and 
             loaded = ::Yito::Model::Rates::PriceDefinition.get(self.price_definition_1.id)
            p "exist 1"
            self.price_definition_1 = loaded
          end
          if self.price_definition_1 and self.price_definition_1.id.nil?
            p "new 1"
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