require 'spec_helper'

describe BookingDataSystem::Booking do 

  let(:booking_online) {{'date_from' => Time.utc(2013, 3, 1).to_s,
      	'date_to' => Time.utc(2013,3, 3).to_s ,
      	'item_id' => 'A',
        'item_description' => 'CLASE A',
      	'item_cost' => 30,
      	'extras_cost' => 20,
      	'total_cost' => 50,
      	'booking_amount' => 20,
      	'payment_method_id' => 'cecabank',
      	'quantity' => 1,
      	'date_to_price_calculation' => Time.utc(2013, 3, 3).to_s,
      	'days' => 2,
      	'customer_name' => 'Mr. John',
      	'customer_surname' => 'Smith',
      	'customer_email' => 'john.smith@test.com',
      	'customer_phone' => '935551010',
      	'customer_mobile_phone' => '666101010',
      	'comments' => 'Nothing',
       	'booking_extras' => [{'extra_id' => 'cuna',
                           'extra_description' => 'cuna description',
      		                 'extra_cost' => 20,
      		                 'extra_unit_cost' => 10,
      		                 'quantity' => 1}]
        }}

  let(:booking_offline) {{'date_from' => Time.utc(2013, 4, 1).to_s,
      	'date_to' => Time.utc(2013, 4, 4).to_s ,
      	'item_id' => 'B',
        'item_description' => 'CLASE B',
      	'item_cost' => 40,
      	'extras_cost' => 30,
      	'total_cost' => 70,
      	'booking_amount' => 28,
      	'payment_method_id' => 'bank_transfer',
      	'quantity' => 1,
      	'date_to_price_calculation' => Time.utc(2013, 4, 4).to_s,
      	'days' => 3,
      	'customer_name' => 'Mrs. Joan',
      	'customer_surname' => 'Green',
      	'customer_email' => 'joan.green@test.com',
      	'customer_phone' => '935559999',
      	'customer_mobile_phone' => '666999999',
      	'comments' => 'No comments',
       	'booking_extras' => [{'extra_id' => 'trona',
                           'extra_description' => 'trona description',
      		                 'extra_cost' => 30,
      		                 'extra_unit_cost' => 10,
      		                 'quantity' => 1}]
        }}

  let(:booking_no_payment_method) {{'date_from' => Time.utc(2013, 5, 1).to_s,
      	'date_to' => Time.utc(2013, 5, 5).to_s ,
      	'item_id' => 'C',
        'item_description' => 'CLASE C',
      	'item_cost' => 50,
      	'extras_cost' => 40,
      	'total_cost' => 90,
      	'quantity' => 1,
      	'date_to_price_calculation' => Time.utc(2013, 5, 5).to_s,
      	'days' => 4,
      	'customer_name' => 'Mr. Mike',
      	'customer_surname' => 'Jones',
      	'customer_email' => 'mike.jones@test.com',
      	'customer_phone' => '0034935559999',
      	'customer_mobile_phone' => '0034666999999',
      	'comments' => 'No comments',
       	'booking_extras' => [{'extra_id' => 'alarma',
                           'extra_description' => 'alarma description',
      		                 'extra_cost' => 40,
      		                 'extra_unit_cost' => 10,
      		                 'quantity' => 1}]
        }}

  describe "#save" do

    context "online payment method (deposit)" do

      subject { BookingDataSystem::Booking.create(booking_online) }
      its(:charges) { should_not be_empty }
      its("charges.first.amount") { should == booking_online['booking_amount']}
      its("booking_charges.first.charge_detail") { should_not be_nil }
      its("booking_charges.first.charge_detail") { should be_an_instance_of (Array) }
      its("booking_charges.first.charge_detail.first") { should include(
         :item_reference => 'DEPOSIT', :item_description => 'CLASE A',
         :item_units => 1)}
      #its("booking_charges.first.charge_detail.first") { should include( 
      #  :item_reference => 'A', :item_description => 'CLASE A', 
      #  :item_units => 1) }
      #its("booking_charges.first.charge_detail.last") { should include(
      #  :item_reference => 'cuna', :item_description => 'cuna description',
      #  :item_units => 1)}

    end

    context "online payment method (full)" do

    end

    context "offline payment method" do

      subject { BookingDataSystem::Booking.create(booking_offline) }
      its(:charges) { should be_empty }

    end

    context "no payment method" do

      subject { BookingDataSystem::Booking.create(booking_no_payment_method) }
      its(:charges) { should be_empty }

    end

  end

end