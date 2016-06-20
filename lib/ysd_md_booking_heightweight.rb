module BookingDataSystem
  #
  # Represent the number of people for a booking
  #
  module BookingHeightWeight
    def self.included(model)
      
      if model.respond_to?(:property)
        model.property :customer_height, String, :length => 20
        model.property :customer_weight, String, :length => 20
        model.property :customer_2_height, String, :length => 20
        model.property :customer_2_weight, String, :length => 20
      end
      
    end
  end
end