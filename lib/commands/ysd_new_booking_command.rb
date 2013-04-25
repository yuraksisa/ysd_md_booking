require 'json' unless defined?JSON
require 'ysd-md-business_events' unless defined?BusinessEvents

module Commands
  #
  # Notify a new booking
  #
  class NewBookingBusinessEventCommand < BusinessEvents::BusinessEventCommand
      
    def execute
      data = JSON.parse(business_event.data)
      if booking = BookingDataSystem::Booking.get(data['booking_id'])
        booking.notify_manager
      end
    end
  
  end #NewBookingBusinessEventCommand
end # Commands