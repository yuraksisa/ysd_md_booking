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

     has n, :prereservation_lines, 'BookingPrereservationLine', :constraint => :destroy, :child_key => [:prereservation_id]

     before :save do |prereservation|

       data = BookingDataSystem::Booking.calculate_days(self.date_from, self.time_from, self.date_to, self.time_to)
       prereservation.days = data[:days]

     end

  end
end