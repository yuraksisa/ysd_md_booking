module BookingDataSystem
  #
  # Represent the number of people for a booking
  #
  module BookingGuests
    def self.included(model)
      
      if model.respond_to?(:property)
        model.property :number_of_adults, Integer, :field => 'number_of_adults', :default => 0
        model.property :number_of_children, Integer, :field => 'number_of_children', :default => 0
      end
      
    end
  end
end