require 'json' unless defined?JSON
require 'sinatra/r18n' unless defined?R18n
require 'ysd-md-business_events' unless defined?BusinessEvents

module Commands
  #
  # Notify a new booking
  #
  class NewBookingBusinessEventCommand < BusinessEvents::BusinessEventCommand
       include R18n::Helpers 
      
    def execute
      data = JSON.parse(business_event.data)
      if booking = BookingDataSystem::Booking.get(data['booking_id'])
        booking.notify_new_booking
      end
    end
  
  end #NewBookingBusinessEventCommand
end # Commands