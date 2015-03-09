require 'data_mapper' unless defined?DataMapper

module BookingDataSystem
  # 
  # Represent a booking line with a item and a quantity
  #
  class BookingLine
     include DataMapper::Resource
     storage_names[:default] = 'bookds_bookings_lines' 
 
     property :id, Serial
     property :item_id, String, :length => 20, :required => true
     property :item_description, String, :length => 256
     property :optional, String, :length => 40
     property :item_unit_cost, Decimal, :precision => 10, :scale => 2
     property :item_cost, Decimal, :precision => 10, :scale => 2
     property :quantity, Integer
     belongs_to :booking, 'Booking', :child_key => [:booking_id]
     has n, :booking_line_resources, 'BookingLineResource', :constraint => :destroy 

  end
end