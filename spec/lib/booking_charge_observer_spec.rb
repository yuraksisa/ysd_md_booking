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
      	:payment => 'deposit',
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
    
    context "charge done : deposit" do
       
       it "should confirm the booking" do
         SystemConfiguration::Variable.should_receive(:get_value).with('booking.deposit','0').and_return('40')
         booking = BookingDataSystem::Booking.create(booking_data) 
         charge = booking.charges.first
         charge.should_receive(:charge_source).any_number_of_times.and_return(booking.booking_charges.first)
         booking.should_receive(:confirm)

         charge.update({:status => :done})

         booking.total_paid.should == charge.amount
         booking.total_pending.should == booking.total_cost - booking.total_paid
         booking.payment_status.should == :deposit

       end

    end

    context "two charges : deposit and pending" do

       it "should process two charges" do
         SystemConfiguration::Variable.should_receive(:get_value).with('booking.notification_email')
         SystemConfiguration::Variable.should_receive(:get_value).with('booking.deposit','0').and_return('40')

         # First charge (automatically created)
         booking = BookingDataSystem::Booking.create(booking_data) 
         charge = booking.charges.first
         charge.should_receive(:charge_source).any_number_of_times.and_return(booking.booking_charges.first)

         charge.update({:status => :done})

         booking.total_paid.should == charge.amount
         booking.total_pending.should == booking.total_cost - booking.total_paid
         booking.status = :confirmed
         booking.payment_status == :deposit

         # Second charge
         booking.create_online_charge!('pending', :pi4b)
         charge = booking.charges.last
         charge.should_receive(:charge_source).any_number_of_times.and_return(booking.booking_charges.last)

         charge.update({:status => :done})

         booking.total_paid.should == booking.total_cost
         booking.total_pending.should == 0
         booking.status == :confirmed
         booking.payment_status == :total

       end
       

    end

    context "charge denied (deposit)" do
       
       it "should not confirm the booking" do
         SystemConfiguration::Variable.should_receive(:get_value).with('booking.deposit','0').and_return('40')
         booking = BookingDataSystem::Booking.create(booking_data) 
         charge = booking.charges.first
         charge.should_receive(:charge_source).any_number_of_times.and_return(booking.booking_charges.first)
         booking.should_not_receive(:confirm)         
         
         charge.update({:status => :denied})
         booking.status.should == :pending_confirmation 
       end

    end

  end

end