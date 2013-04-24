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
    # Updates the booking status
    #
    after :update do |charge|
      
      if charge.charge_source.is_a?BookingDataSystem::BookingCharge 
        booking = charge.charge_source.booking
        if booking.status == :confirming
          case charge.status
            when :done
              booking.update(:status => :confirmed)
            when :denied
              booking.update(:status => :pending_confirmation)
          end
        end
      end
      
    end
    
  end
end