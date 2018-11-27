require 'data_mapper' unless defined?DataMapper

module Yito
  module Model
    module Booking
      #
      # It represents business and their basic configurations
      #
      # It allows to setup the process depending on the business :
      #
      #   - car rental
      #   - hostels
      #   -
      #   - tours
      #   - activities
      #
      class ProductFamily
        include DataMapper::Resource

        storage_names[:default] = 'bookds_families'
      
        property :code, String, :field => 'code', :length => 20, :key => true
        property :name, String, :length => 255
        property :presentation_order, Integer

        # Product type
        property :product_type, Enum[:category_of_resources, :resource], :default => :category_of_resources
        # Business type
        property :business_type, Enum[:vehicle_rental, :accommodation, :boat_charter, :ads,
                                      :category_resources, :resources, :tours, :activities,
                                      :vehicle_rental_resources], default: :vehicle_rental
        # Business activity
        property :business_activity, Enum[:rental, :activities_tours, :both_rental_activities_tours], default: :rental
        # Frontend
        property :frontend, Enum[:dates, :categories, :shopcart, :calendar], :default => :dates

        # Product price builder
        property :product_price_definition_type, Enum[:season, :no_season], default: :season
        belongs_to :product_price_definition_season_definition, 'Yito::Model::Rates::SeasonDefinition',
                   :child_key => [:product_price_definition_season_definition_id], :parent_key => [:id], :required => false
        belongs_to :product_price_definition_factor_definition, 'Yito::Model::Rates::FactorDefinition',
                   :child_key => [:product_price_definition_factor_definition_id], :parent_key => [:id], :required => false
        property :product_price_definition_units_management, Enum[:unitary, :detailed], default: :detailed
        property :product_price_definition_units_management_value, Integer, default: 7

        # Extras price builder
        property :allow_extras, Boolean, default: true
        property :extras_price_definition_type, Enum[:season, :no_season], default: :no_season
        property :extras_price_definition_units_management, Enum[:unitary, :detailed], default: :unitary
        property :extras_price_definition_units_management_value, Integer, default: 1
        belongs_to :extras_price_definition_season_definition, 'Yito::Model::Rates::SeasonDefinition',
                   :child_key => [:extras_price_definition_season_definition_id], :parent_key => [:id], :required => false
        belongs_to :extras_price_definition_factor_definition, 'Yito::Model::Rates::FactorDefinition',
                   :child_key => [:extras_price_definition_factor_definition_id], :parent_key => [:id], :required => false

        # Rental configuration
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
        property :stock_model, Boolean, :default => false
        property :stock_plate, Boolean, :default => false
        property :starting_date, Enum[:pickup_return_date, :checkin_checkout, :start_end_date, :start_end, :arrive_departure_date, :arrive_departure], default: :pickup_return_date

        # Characteristics (up to 4 characteristics for inventory items)
        property :stock_characteristic_1, String, length: 80
        property :stock_characteristic_2, String, length: 80
        property :stock_characteristic_3, String, length: 80
        property :stock_characteristic_4, String, length: 80

        # ------ Helpers that represents the categories of the business ------------------------------------------

        #
        # If the business activity includes rental
        #
        def rental?
          business_activity == :rental or business_activity == :both_rental_activities_tours
        end

        #
        # If the business activity include activities/tours
        #
        def activities_tours?
          business_activity == :activities_tours or business_activity == :both_rental_activities_tours
        end

        #
        # The business manages categories of resources (like car rentals, hotels, ...)
        #
        def category_of_resources?
          product_type == :category_of_resources
        end

        #
        # The business manages resources (like ads, boat charters, ....)
        #
        def resource?
          product_type == :resource
        end

        def vehicle_rental?
          business_type == :vehicle_rental
        end

        def accommodation?
          business_type == :accommodation
        end

        def boat_charter?
          business_type == :boat_charter
        end

        def ads?
          business_type == :ads
        end

        def category_resources?
          business_type == :category_resources
        end

        def resources?
          business_type == :resources
        end

        def pickup_return_date?
          starting_date == :pickup_return_date
        end

        def checkin_checkout?
          starting_date == :checkin_checkout
        end

        def start_end_date?
          starting_date == :start_end_date
        end

        def start_end?
          starting_date == :start_end
        end

        def arrive_departure_date?
          starting_date == :arrive_departure_date
        end

        def arrive_departure?
          starting_date == :arrive_departure
        end

        def product_price_season?
          product_price_definition_type == :season
        end

        def product_price_no_season?
          product_price_definition_type == :no_season
        end

        def extras_price_season?
          extras_price_definition_type == :season
        end

        def extras_price_no_season?
          extras_price_definition_type == :no_season
        end

        #
        # Check if the product allows multiple items
        #
        def multiple_items?
          self.frontend == :shopcart
        end

        # ----------------------------------------------------------------------------------------------------------

        #
        # Build a generic product price
        #
        def build_product_price_definition(name, description)

          season_definition = nil
          factor_definition = nil
          
          # The season definition
          if product_price_definition_type == :season
            if new_season_definition_instance = SystemConfiguration::Variable.get_value('booking.new_season_definition_instance_for_category','false').to_bool
              season_definition = self.product_price_definition_season_definition.make_copy unless self.product_price_definition_season_definition.nil?
            else
              season_definition = self.product_price_definition_season_definition
            end
          end  
          
          # The factor definition
          if use_factors = SystemConfiguration::Variable.get_value('booking.use_factors_in_rates', 'false').to_bool
            if new_factor_definition_instance = SystemConfiguration::Variable.get_value('booking.new_factor_definition_instance_for_category','false').to_bool
              factor_definition = self.product_price_definition_factor_definition.make_copy unless self.product_price_definition_factor_definition.nil?
            else
              factor_definition = self.product_price_definition_factor_definition
            end
          end
          
          # The price definition
          price_definition = Yito::Model::Rates::PriceDefinition.new(
                              name: name,
                              description: description,
                              type: product_price_definition_type,
                              units_management: product_price_definition_units_management,
                              units_management_value: product_price_definition_units_management_value,
                              season_definition: season_definition,
                              factor_definition: factor_definition)

        end

        #
        # Build a generic extra price
        #
        def build_extras_price_definition(name, description)

          use_factors = SystemConfiguration::Variable.get_value('booking.use_factors_in_extras_rates', 'false').to_bool

          price_definition = Yito::Model::Rates::PriceDefinition.new(
              name: name,
              description: description,
              type: extras_price_definition_type,
              units_management: extras_price_definition_units_management,
              units_management_value: extras_price_definition_units_management_value,
              season_definition: (extras_price_definition_type == :season ? extras_price_definition_season_definition : nil),
              factor_definition: use_factors ? extras_price_definition_factor_definition : nil)

        end

      end
    end
  end
end