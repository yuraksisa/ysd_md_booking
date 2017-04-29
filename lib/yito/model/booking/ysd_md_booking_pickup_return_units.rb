module Yito
  module Model
    module Booking
      module BookingPickupReturnUnits
        def self.included(model)

          if model.respond_to?(:property)
            model.property :km_miles_on_pickup, Integer
            model.property :km_miles_on_return, Integer
          end

        end
      end
    end
  end
end