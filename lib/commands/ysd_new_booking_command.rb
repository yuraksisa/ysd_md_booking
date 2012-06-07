require 'ysd-md-profile' unless defined?Profile
require 'json' unless defined?JSON
#require 'ysd_service_template' unless defined?TemplateService
#require 'ysd_service_postal' unless defined?PostalService
require 'sinatra/r18n' unless defined?R18n

# -----------------------------------------------------------------------
# Process a new booking
# -----------------------------------------------------------------------
#  It sends an email to the company
# -----------------------------------------------------------------------
class NewBookingBusinessEventCommand < BusinessEvents::BusinessEventCommand
      include R18n::Helpers 
      
  def execute
      
      data = JSON.parse(business_event.data)
      
      # Loads the booking
      booking = BookingDataSystem::Booking.get(data['booking_id'])
      
      puts "booking : #{booking.to_json}"
      
      # Notify the booking      
      booking.notify_new_booking if booking
  
  end

end