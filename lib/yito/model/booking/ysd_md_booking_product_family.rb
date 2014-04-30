require 'data_mapper' unless defined?DataMapper

module Yito
  module Model
    module Booking
      #
      # It represents the booking product family. 
      #
      # This class allows the configuration of the different product families
      #  
      #
      class ProductFamily
        include DataMapper::Resource

        storage_names[:default] = 'bookds_families'
      
        property :code, String, :field => 'code', :length => 20, :key => true
        property :driver, Boolean, :field => 'driver', :default => false
        property :guests, Boolean, :field => 'guests', :default => false
        property :flight, Boolean, :field => 'flight', :default => false
        property :pickup_return_place, Boolean, :field => 'pickup_return_place', :default => false
        property :time_to_from, Boolean, :field => 'time_to_from', :default => false
        property :start_date_literal, Enum[:arrival, :pickup], :field => 'start_date_literal', :default => :arrival  
      
      end
    end
  end
end