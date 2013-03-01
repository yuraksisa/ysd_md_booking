require 'data_mapper' unless defined?DataMapper

module BookingDataSystem

  # ---------------------------------------- 
  # This represents an booking for a item
  # ----------------------------------------
  class Booking 
     include DataMapper::Resource
     include BookingNotifications
    
     storage_names[:default] = 'bookds_bookings' # stored in bookings table in default storage
     
     property :id, Serial, :field => 'id'
     
     property :creation_date, DateTime, :field => 'creation_date'  # The creation date
     property :source, String, :field => 'source', :length => 50   # Where does the booking come from
     
     property :date_from, DateTime, :field => 'date_from', :required => true
     property :time_from, String, :field => 'time_from', :required => true, :length => 5
     property :date_to, DateTime, :field => 'date_to', :required => true 
     property :time_to, String, :field => 'time_to', :required => true, :length => 5
     
     property :item_id, String, :field => 'item_id', :required => true, :length => 20
     
     property :item_cost, Decimal, :field => 'item_cost', :scale => 2, :precision => 10
     property :extras_cost, Decimal, :field => 'extras_cost', :scale => 2, :precision => 10
     property :total_cost, Decimal, :field => 'total_cost', :scale => 2, :precision => 10
     
     property :quantity, Integer, :field => 'quantity'
     property :date_to_price_calculation, DateTime, :field => 'date_to_price_calculation'
     property :days, Integer, :field => 'days'
     
     property :customer_name, String, :field => 'customer_name', :required => true, :length => 40
     property :customer_surname, String, :field => 'customer_surname', :required => true, :length => 40
     property :customer_email, String, :field => 'customer_email', :required => true, :length => 40
     property :customer_phone, String, :field => 'customer_phone', :required => true, :length => 15 
     property :customer_mobile_phone, String, :field => 'customer_mobile_phone', :length => 15
     
     property :comments, String, :field => 'comments', :length => 1024
     
     has n, :booking_extras, 'BookingExtra' 
     
     before :create do |booking|
       booking.creation_date = Time.now if not booking.creation_date
     end
     
     after :create do |booking|
       BusinessEvents::BusinessEvent.fire_event(:new_booking, 
         {:booking_id => booking.id})
     end
          
  end

   

end