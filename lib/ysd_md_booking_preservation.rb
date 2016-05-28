require 'data_mapper' unless defined?DataMapper

module BookingDataSystem

  # 
  # Represent a prereservation of an stock item for a period
  #
  class BookingPrereservation
     include DataMapper::Resource

     storage_names[:default] = 'bookds_prereservations' 
     
     property :id, Serial
     property :booking_item_reference, String, :length => 50
     property :date_from, DateTime, :required => true
     property :time_from, String, :required => false, :length => 5
     property :date_to, DateTime, :required => true 
     property :time_to, String, :required => false, :length => 5
     property :title, String, :length => 256
     property :notes, Text

  end
end