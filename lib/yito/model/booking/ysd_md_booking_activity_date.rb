module Yito
  module Model
    module Booking
      #
      # It represents an activity date 
      #
      class ActivityDate
        include DataMapper::Resource
        extend  Yito::Model::Finder

        storage_names[:default] = 'bookds_activity_dates'

        property :id, Serial
        property :date_from, DateTime
        property :time_from, String, :length => 5
        property :date_to, DateTime
        property :time_to, String, :length => 5 
        property :override_capacity, Boolean, :default => false
        property :capacity, Integer, :default => 0
        property :description, Text

        belongs_to :activity, 'Yito::Model::Booking::Activity'

      end
    end
  end
end