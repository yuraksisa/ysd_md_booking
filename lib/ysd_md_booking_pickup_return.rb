module BookingDataSystem
  #
  # Represent the places where the booking item is picked up and returned
  #
  module BookingPickupReturn
    def self.included(model)
      if model.respond_to?(:property)
        model.property :pickup_place, DataMapper::Property::Text, :field => 'pickup_place'
        model.property :pickup_place_customer_translation, DataMapper::Property::Text
        model.property :return_place, DataMapper::Property::Text, :field => 'return_place'
        model.property :return_place_customer_translation, DataMapper::Property::Text
        model.property :pickup_place_cost, DataMapper::Property::Decimal, :scale => 2, :precision => 10, :default => 0
        model.property :return_place_cost, DataMapper::Property::Decimal, :scale => 2, :precision => 10, :default => 0        
      end	
    end
  end #BookingPickupReturn
end #BookingDataSystem