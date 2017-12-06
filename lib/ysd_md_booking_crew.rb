module BookingDataSystem
  #
  # Booking boat information
  #
  module BookingCrew
    def self.included(model)
      if model.respond_to?(:property)
        model.property :include_crew, DataMapper::Property::Boolean, :default => false
      end
    end
  end
end