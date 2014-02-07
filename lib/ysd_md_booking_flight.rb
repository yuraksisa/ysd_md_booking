module BookingDataSystem
  #
  # Booking flight information
  #
  module BookingFlight
    def self.included(model)
      if model.respond_to?(:property)
        model.property :flight_company, String, :length => 80
        model.property :flight_number, String, :length => 10
        model.property :flight_time, String, :length => 5
      end
    end
  end
end