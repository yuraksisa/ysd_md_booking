module BookingDataSystem
  #
  # Booking fuel information
  #
  module BookingFuel
    FUEL = ['1/8','2/8','3/8','4/8','5/8','6/8','7/8','8/8']
    def self.included(model)
      if model.respond_to?(:property)
        model.property :pickup_fuel, String, :length => 3
        model.property :return_fuel, String, :length => 3
      end
    end
  end
end