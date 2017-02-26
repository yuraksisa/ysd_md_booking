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
     property :extra_unit_cost, Decimal, :field => 'extra_unit_cost', :scale => 2, :precision => 10, :default => 0
     property :extra_cost, Decimal, :field => 'extra_cost', :scale => 2, :precision => 10, :default => 0
     property :quantity, Integer, :field => 'quantity'
     
     belongs_to :booking, 'Booking', :child_key => [:booking_id]

     def save
      super # Invokes the super class to achieve the chain of methods invoked       
     end

     # --------------------------- Reservation items management -----------------------------------------

     #
     # Change the extra quantity
     #
     def update_quantity(new_quantity)

       if extra = ::Yito::Model::Booking::BookingExtra.get(self.extra_id)
         booking_deposit = SystemConfiguration::Variable.get_value('booking.deposit', 0).to_i
         old_quantity = self.quantity
         old_booking_extra_extra_cost = self.extra_cost
         self.transaction do
           self.quantity = new_quantity
           self.extra_cost = self.extra_unit_cost * quantity
           self.save
           # Update the booking (cost)
           extra_cost_increment = self.extra_cost - old_booking_extra_extra_cost
           total_cost_increment = extra_cost_increment
           booking.extras_cost += extra_cost_increment
           booking.total_cost += total_cost_increment
           booking.total_pending += total_cost_increment
           booking.booking_amount += (total_cost_increment * booking_deposit / 100).round unless booking_deposit == 0
           booking.save
         end
         booking.reload
       end

     end

     #
     # Update extra cost
     #
     def update_cost(new_extra_unit_cost)

       if extra = ::Yito::Model::Booking::BookingExtra.get(self.extra_id)
         booking_deposit = SystemConfiguration::Variable.get_value('booking.deposit', 0).to_i
         old_booking_extra_extra_cost = self.extra_cost
         self.transaction do
           self.extra_unit_cost = new_extra_unit_cost
           self.extra_cost = booking_extra.extra_unit_cost * booking_extra.quantity
           self.save
           # Update the booking (cost)
           extra_cost_increment = self.extra_cost - old_booking_extra_extra_cost
           total_cost_increment = extra_cost_increment
           booking.extras_cost += extra_cost_increment
           booking.total_cost += total_cost_increment
           booking.total_pending += total_cost_increment
           booking.booking_amount += (total_cost_increment * booking_deposit / 100).round unless booking_deposit == 0
           booking.save
         end
         booking.reload
       end

     end

     # -----------------------------------------------------------------------------------------------------------

  end
end