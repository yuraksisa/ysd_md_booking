require 'json' unless defined?JSON
require 'sinatra/r18n' unless defined?R18n
require 'ysd-md-business_events' unless defined?BusinessEvents

# -----------------------------------------------------------------------
# Process a new booking
# -----------------------------------------------------------------------
#  It sends an email to the company
# -----------------------------------------------------------------------
class NewBookingBusinessEventCommand < BusinessEvents::BusinessEventCommand
      include R18n::Helpers 
      
  def execute
      
    data = JSON.parse(business_event.data)
    
    if booking = BookingDataSystem::Booking.get(data['booking_id'])
      booking.notify_new_booking
    end

  end

end