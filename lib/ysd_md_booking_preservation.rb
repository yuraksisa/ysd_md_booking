require 'data_mapper' unless defined?DataMapper

module BookingDataSystem

  # 
  # Represent a prereservation of an stock item for a period
  #
  class BookingPrereservation
     include DataMapper::Resource

     storage_names[:default] = 'bookds_prereservations' 
     
     property :id, Serial
     property :booking_item_category, String, :length => 20
     property :booking_item_reference, String, :length => 50
     property :date_from, DateTime, :required => true
     property :time_from, String, :required => false, :length => 5
     property :date_to, DateTime, :required => true 
     property :time_to, String, :required => false, :length => 5
     property :title, String, :length => 256
     property :notes, Text
     property :planning_color, String, :length => 9
     property :days, Integer

     before :save do |b|
       b.days = (date_to - date_from).to_i
       hours_of_difference = (date_to - date_from).to_f.modulo(1) * 24
       b.days = b.days + 1 if hours_of_difference > 2
     end

  end
end