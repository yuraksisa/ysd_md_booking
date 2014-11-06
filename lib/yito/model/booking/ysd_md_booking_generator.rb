require 'singleton'
module Yito
  module Model
  	module Booking
  	  class Generator  
  	    include Singleton

        def build_script

          
          booking_extras = BookingExtra.all
          booking_categories = BookingCategory.all
          season_definition = ::Yito::Model::Rates::SeasonDefinition.first
          factor_definition = ::Yito::Model::Rates::FactorDefinition.first
          place_definition = PickupReturnPlaceDefinition.first
          pickup_places = PickupReturnPlace.all(:place_definition_id => place_definition.id, :is_pickup => true)
          return_places = PickupReturnPlace.all(:place_definition_id => place_definition.id, :is_return => true)

          template_file = File.expand_path(File.join(File.dirname(__FILE__), "..", "..", "..", "..",
             "templates", "booking.js.erb"))
          template = ERB.new File.read(template_file)
          message = template.result(binding)

        end

  	  end
  	end
  end
end