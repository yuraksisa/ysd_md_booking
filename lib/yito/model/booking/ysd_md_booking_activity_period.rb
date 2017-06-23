module Yito
  module Model
    module Booking
      #
      # It represents a period of a cyclic activity 
      #
      class ActivityPeriod
        include DataMapper::Resource
        extend  Yito::Model::Finder

        storage_names[:default] = 'bookds_activity_periods'

        property :id, Serial

        # To manage if the activity is offered all year or only on specific period
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


        belongs_to :activity, 'Yito::Model::Booking::Activity'

      end
    end
  end
end