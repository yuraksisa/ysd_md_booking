require 'spec_helper'


describe BookingDataSystem::BookingChargeObserver do
	
    let(:booking_data) {
  	   {:date_from => Time.utc(2013, 3, 1).to_s,
      	:date_to => Time.utc(2013,3, 3).to_s ,
      	:item_id => 'D',
        :item_description => 'CLASE D',
      	:item_cost => 30,
      	:extras_cost => 20,
      	:total_cost => 50,
      	:booking_amount => 20,
      	:payment_method_id => :pi4b,
      	:quantity => 1,
      	:date_to_price_calculation => Time.utc(2013, 3, 3).to_s,
      	:days => 2,
      	:customer_name => 'Mr. John',
      	:customer_surname => 'Smith',
      	:customer_email => 'john.smith@test.com',
      	:customer_phone => '935551010',
      	:customer_mobile_phone => '666101010',
      	:comments => 'Nothing',
       	:booking_extras => [{'extra_id' => 'cuna',
                           'extra_description' => 'cuna description',
      		                 'extra_cost' => 20,
      		                 'extra_unit_cost' => 10,
      		                 'quantity' => 1}]
        }
    }

  describe "charge update" do
    
    context "charge done" do

       subject do
         booking = BookingDataSystem::Booking.create(booking_data) 
         charge = booking.charges.first
         booking.update({:status => :confirming})
         charge.update({:status => :done})
         booking = BookingDataSystem::Booking.get(booking.id)
       end

       its(:status) { should == :confirmed }

    end

    context "charge denied" do

       subject do
         booking = BookingDataSystem::Booking.create(booking_data) 
         charge = booking.charges.first
         booking.update({:status => :confirming})
         charge.update({:status => :denied})
         booking = BookingDataSystem::Booking.get(booking.id)
       end

       its(:status) { should == :pending_confirmation }

    end

  end

end