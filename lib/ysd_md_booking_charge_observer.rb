require 'dm-observer' unless defined?DataMapper::Observer
require 'ysd_md_charge' unless defined?Payments::Charge

module BookingDataSystem
  #
  # Observes changes on the charge tied to the booking to update the booking
  # status depending on the charge status change
  #
  # - If the charge status is set to done, the booking status is set to
  #   confirmed
  #
  # - If the charge status is set to denied, the booking status is set to
  #   pending_confirmation
  #	
  class BookingChargeObserver
    include DataMapper::Observer

    observe Payments::Charge
    
    #
    # After updating a charge
    #
    #  - Updates the booking payment_status
    #  - Updates the total_paid and total_pending quantities
    #
    #  * Confirms the booking if the status is pending_confirmation
    #
    after :update do |charge|

      if charge.charge_source.is_a?BookingDataSystem::BookingCharge 
        booking = charge.charge_source.booking
        case charge.status
          when :done
            booking.total_paid += charge.amount
            booking.total_pending -= charge.amount
            if (booking.total_pending == 0)
              booking.payment_status = :total
            else
              booking.payment_status = :deposit
            end
            if booking.status == :pending_confirmation           
              booking.confirm
            else
              booking.save
            end 
          when :denied
            # None
        end
      end
      
    end
    
  end
end