require 'data_mapper' unless defined?DataMapper

module BookingDataSystem
  # 
  # This represents a booking extra
  # 
  class BookingExtra
     include DataMapper::Resource
     
     storage_names[:default] = 'bookds_bookings_extras' 
     
     property :id, Serial, :field => 'id'
     
     property :extra_id, String, :field => 'extra_id', :required => true, :length => 20
     property :extra_description, String, :field => 'extra_description', :required => false, :length => 256
     property :extra_unit_cost, Decimal, :field => 'extra_unit_cost', :scale => 2, :precision => 10
     property :extra_cost, Decimal, :field => 'extra_cost', :scale => 2, :precision => 10
     property :quantity, Integer, :field => 'quantity'
     
     belongs_to :booking, 'Booking', :child_key => [:booking_id]
     
  end
end