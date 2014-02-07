module BookingDataSystem
  #
  # Represent the places where the booking item is picked up and returned
  #
  module BookingPickupReturn
    def self.included(model)
      if model.respond_to?(:property)
        model.property :pickup_place, String, :field => 'pickup_place', :length => 80
        model.property :return_place, String, :field => 'return_place', :length => 80   
      end	
    end
  end #BookingPickupReturn
end #BookingDataSystem