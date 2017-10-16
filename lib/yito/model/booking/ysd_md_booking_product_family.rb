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
        property :name, String, :length => 255
        property :presentation_order, Integer
        property :frontend, Enum[:dates, :categories, :shopcart, :calendar], :default => :dates
        property :driver, Boolean, :field => 'driver', :default => false
        property :driver_date_of_birth, Boolean, :field => 'driver_date_of_birth', :default => false
        property :driver_license, Boolean, :field => 'driver_license', :default => false
        property :guests, Boolean, :field => 'guests', :default => false
        property :flight, Boolean, :field => 'flight', :default => false
        property :height, Boolean, :field => 'height', :default => false
        property :height_mandatory, Boolean, :field => 'height_mandatory', :default => false
        property :height_values, String, :field => 'height_values', :length => 255
        property :weight, Boolean, :field => 'weight', :default => false
        property :weight_mandatory, Boolean, :field => 'weight_mandatory', :default => false
        property :weight_values, String, :field => 'weight_values', :length => 255
        property :pickup_return_place, Boolean, :field => 'pickup_return_place', :default => false
        property :time_to_from, Boolean, :field => 'time_to_from', :default => false
        property :cycle_of_24_hours, Boolean, :field => 'cycle_of_24_hours', :default => true
        property :time_start, String, :field => 'time_start', :length => 5, :default => '10:00'
        property :time_end, String, :field => 'time_end', :length => 5, :default => '20:00'
        property :start_date_literal, Enum[:arrival, :pickup], :field => 'start_date_literal', :default => :arrival  
        property :driver_literal, Enum[:driver, :contact], :field => 'driver_literal', :default  => :driver
        property :named_resources, Boolean, :field => 'named_resources', :default => false
        property :fuel, Boolean, :field => 'fuel', :default => false

        def multiple_items?
          self.frontend == :shopcart
        end
        
      end
    end
  end
end