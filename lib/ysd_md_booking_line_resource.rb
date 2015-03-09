require 'data_mapper' unless defined?DataMapper

module BookingDataSystem
  # 
  # Represent a booking line with a item and a quantity
  #
  class BookingLineResource
     include DataMapper::Resource
     storage_names[:default] = 'bookds_bookings_lines_resources' 
     property :id, Serial
     belongs_to :booking_line, 'BookingLine', :child_key => [:booking_line_id]
     belongs_to :booking_item, 'Yito::Model::Booking::BookingItem', 
       :child_key => [:booking_item_reference], :parent_key => [:reference]
  end
end