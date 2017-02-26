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

     before :save do |prereservation|

       cadence_hours = SystemConfiguration::Variable.get_value('booking.hours_cadence',2).to_i
       prereservation.days = (prereservation.date_to - prereservation.date_from).to_i
       begin
         _t_from = DateTime.strptime(prereservation.time_from,"%H:%M")
         _t_to = DateTime.strptime(prereservation.time_to,"%H:%M")
         if _t_to > _t_from
           hours_of_difference = (_t_to - _t_from).to_f.modulo(1) * 24
           if hours_of_difference > cadence_hours
             prereservation.days += 1
           end
         end
       rescue
         p "Time from or time to are not valid #{prereservation.time_from} #{prereservation.time_from}"
       end

     end

  end
end