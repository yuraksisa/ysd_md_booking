module Yito
  module Model
    module Booking
      #
      # Represents the information about a planned activity
      #	
      class PlannedActivity
        include DataMapper::Resource
        extend  Yito::Model::Finder
        storage_names[:default] = 'bookds_planned_activities'
        property :id, Serial
        property :date, DateTime, :unique_index => :bookds_planned_activities_idx
        property :time, String, :length => 5, :unique_index => :bookds_planned_activities_idx
        property :activity_code, String, :length => 50, :unique_index => :bookds_planned_activities_idx 
        property :notes, Text
        property :capacity, Integer, :default => 0
      end
    end
  end 
end      	