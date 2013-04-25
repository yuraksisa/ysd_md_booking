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
       
       it "should confirm the booking" do
         booking = BookingDataSystem::Booking.create(booking_data) 
         charge = booking.charges.first
         charge.should_receive(:charge_source).any_number_of_times.and_return(booking.booking_charges.first)
         booking.should_receive(:confirm)
         booking.update({:status => :confirming})
         charge.update({:status => :done})
       end

    end

    context "charge denied" do
       
       it "should not confirm the booking" do
         booking = BookingDataSystem::Booking.create(booking_data) 
         charge = booking.charges.first
         charge.should_receive(:charge_source).any_number_of_times.and_return(booking.booking_charges.first)
         booking.should_not_receive(:confirm)         
         booking.update({:status => :confirming})
         charge.update({:status => :denied})
         booking.status.should == :pending_confirmation 
       end

    end

  end

end