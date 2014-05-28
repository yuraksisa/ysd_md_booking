require 'data_mapper' unless defined?DataMapper
require 'ysd_md_payment' unless defined?Payments::Charge

module BookingDataSystem
  #
  # It represents a booking charge
  #
  class BookingCharge
    include DataMapper::Resource

    storage_names[:default] = 'bookds_booking_charges'

    belongs_to :booking, 'Booking', :child_key => [:booking_id], :parent_key => [:id], :key => true
    belongs_to :charge, 'Payments::Charge', :child_key => [:charge_id], :parent_key => [:id], :key => true
    
    #
    # Retrieve the booking associated with a charge
    # 
    def self.booking_from_charge(charge_id)

      if booking_charge = first(:charge => {:id => charge_id })
        booking_charge.booking
      end

    end 

    #
    # Integration with charges (return the charge detail)
    #
    # @return [Array]
    def charge_detail
      
      @charge_detail ||= if booking
                           if booking.total_cost > booking.booking_amount 
      	                     build_deposit_charge_detail
      	                   else
                             build_full_charge_detail
                           end
                         else
                           []
                         end

    end
    
    #
    # Integration with charges. When the charge is going to be charged, notifies
    # the sources
    #
    def charge_in_process

      # None

    end
    
    #
    # Integration with charges
    #
    def charge_source_description
      
      if booking and booking.id
        BookingDataSystem.r18n.t.booking_model.charge_description(booking.id)       
      end

    end
     
    #
    # Integration with charges
    # 
    def charge_source_url
      if booking and booking.id
        "/admin/bookings/#{booking.id}"
      end
    end

    def as_json(opts={})

      methods = opts[:methods] || []
      methods << :charge_source_description
      methods << :charge_source_url

      super(opts.merge(:methods => methods))

    end


    private 
    
    #
    # Builds a deposit charge detail
    #
    def build_deposit_charge_detail

      charge_detail = [{:item_reference => 'DEPOSIT',
      	                :item_description => booking.item_description,
      	                :item_units => 1,
      	                :item_price => booking.booking_amount}]

    end

    #
    # Builds a full charge detail
    #
    # @return [Array]
    def build_full_charge_detail

      charge_detail = []
      charge_detail << {:item_reference => booking.item_id,
                       :item_description => booking.item_description,
                       :item_units => 1,
                       :item_price => booking.item_cost}
      
      booking.booking_extras.each do |booking_extra|
        charge_detail << {:item_reference => booking_extra.extra_id,
                          :item_description => booking_extra.extra_description,
                          :item_units => booking_extra.quantity,
                          :item_price => booking_extra.extra_cost}
      end

      return charge_detail

    end

  end
end

module Payments
  class Charge
    has 1, :booking_charge_source, 'BookingDataSystem::BookingCharge', :constraint => :destroy
  end
end