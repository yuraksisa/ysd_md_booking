require 'spec_helper'
require 'ysd_md_configuration'

describe BookingDataSystem::Booking do 

  let(:booking_online) {{'date_from' => Time.utc(2013, 3, 1).to_s,
      	'date_to' => Time.utc(2013,3, 3).to_s ,
      	'item_id' => 'A',
        'item_description' => 'CLASE A',
      	'item_cost' => 30,
      	'extras_cost' => 20,
      	'total_cost' => 50,
        'payment' => 'deposit',
      	'payment_method_id' => 'cecabank',
      	'quantity' => 1,
      	'date_to_price_calculation' => Time.utc(2013, 3, 3).to_s,
      	'days' => 2,
      	'customer_name' => 'Mr. John',
      	'customer_surname' => 'Smith',
      	'customer_email' => 'john.smith@test.com',
      	'customer_phone' => '935551010',
      	'customer_mobile_phone' => '666101010',
        'customer_language' => 'en',
      	'comments' => 'Nothing',
       	'booking_extras' => [{'extra_id' => 'cuna',
                           'extra_description' => 'cuna description',
      		                 'extra_cost' => 20,
      		                 'extra_unit_cost' => 10,
      		                 'quantity' => 1}]
        }}

  let(:booking_online_charge_done) {
       {:charge => {:amount => 20,
         :currency => :EUR,
         :payment_method_id => 'cecabank',
         :status => :done}
       }
  }

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

      subject do
        SystemConfiguration::Variable.should_receive(:get_value).with('booking.deposit','0').and_return('40')
        BookingDataSystem::Booking.create(booking_online) 
      end

      its(:total_paid) { should == 0}
      its(:payment) { should == 'deposit' }
      its(:booking_amount) { should == 20 }
      its(:total_pending) { should == 50}
      its(:charges) { should_not be_empty }
      its("charges.first.amount") { should == 20}
      its("booking_charges.first.charge_detail") { should_not be_nil }
      its("booking_charges.first.charge_detail") { should be_an_instance_of (Array) }
      its("booking_charges.first.charge_detail.first") { should include(
         :item_reference => 'DEPOSIT', :item_description => 'CLASE A',
         :item_units => 1)}

    end

    context "online payment method (total)" do

      subject do
        BookingDataSystem::Booking.create(booking_online.merge({:payment => 'total'})) 
      end

      its(:total_paid) { should == 0}
      its(:payment) { should == 'total' }
      its(:booking_amount) { should == 50 }
      its(:total_pending) { should == 50}
      its(:charges) { should_not be_empty }
      its("charges.first.amount") { should == 50}
      its("booking_charges.first.charge_detail") { should_not be_nil }
      its("booking_charges.first.charge_detail") { should be_an_instance_of (Array) }
      its("booking_charges.first.charge_detail.first") { should include(
         :item_reference => 'A', :item_description => 'CLASE A',
         :item_units => 1)}

    end

    context "offline payment method" do
      
      subject do
        booking = BookingDataSystem::Booking.new(booking_offline) 
        booking.should_receive(:notify_manager)
        booking.should_receive(:notify_request_to_customer)
        booking.save
        booking
      end

      its(:charges) { should be_empty }

    end

    context "no payment method" do

      subject { BookingDataSystem::Booking.create(booking_no_payment_method) }
      its(:charges) { should be_empty }

    end

    context "free_access_id retrieval" do
      let(:booking) { BookingDataSystem::Booking.create(booking_no_payment_method)  }
      subject { BookingDataSystem::Booking.get_by_free_access_id(booking.free_access_id) }
      it { should_not be_nil}
      its(:id) { should == booking.id }
    
    end
    

  end

  describe "#confirm" do

    context "booking pending confirmation" do

      subject do
        SystemConfiguration::Variable.should_receive(:get_value).
          with("booking.notification_email").once.and_return("myaccount@domain.com")
        ContentManagerSystem::Template.should_receive(:first).
          with(:name => "booking_customer_notification_en").once.and_return(nil)
        ContentManagerSystem::Template.should_receive(:first).
          with(:name => "booking_customer_notification").once.
          and_return(ContentManagerSystem::Template.new(
            {:text => "Notificacion cliente"}))
        ContentManagerSystem::Template.should_receive(:first).
          with(:name => "booking_manager_notification").once.
          and_return(ContentManagerSystem::Template.new(
            {:text =>"Manager Notification"}))          
        BookingDataSystem::Notifier.stub_chain(:delay, :notify_customer).
          with('john.smith@test.com', 
            BookingDataSystem.r18n.t.notifications.customer_email_subject, 
            'Notificacion cliente', 
            anything)
        BookingDataSystem::Notifier.stub_chain(:delay, :notify_manager).
          with('myaccount@domain.com', 
            BookingDataSystem.r18n.t.notifications.manager_email_subject, 
            'Manager Notification', 
            anything)
        
        data = booking_online.merge(:booking_charges => [booking_online_charge_done])
        booking = BookingDataSystem::Booking.new(data)
        booking.should_not_receive(:new_charge!)

        booking.save
        booking.confirm
      end

      its(:status) { should == :confirmed }

    end

  end

  describe "#confirm!" do

    context "pending_of_confirmation booking" do

      subject do
        booking = BookingDataSystem::Booking.create(booking_offline)
        booking.confirm!
      end

      its(:status) { should == :confirmed }

    end

    context "not pending_of_confirmation booking" do

      subject do
        booking = BookingDataSystem::Booking.create(booking_offline.merge(:status => :confirmed))
        booking.should_not_receive(:update)
        booking.confirm!
      end

      its(:status) {should == :confirmed}

    end

  end

  describe "#pickup_item" do

    context "confirmed booking" do
    
      subject do
        booking = BookingDataSystem::Booking.create(booking_offline.merge(:status => :confirmed))
        booking.pickup_item
      end

      its (:status) {should == :in_progress}

    end

    context "not confirmed booking" do

      subject do
        booking = BookingDataSystem::Booking.create(booking_offline)
        booking.should_not_receive(:update)
        booking.pickup_item
      end

      its (:status) {should == :pending_confirmation}

    end

  end

  describe "#return_item" do

    context "in_progress booking" do
    
      subject do
        booking = BookingDataSystem::Booking.create(booking_offline.merge(:status => :in_progress))
        booking.return_item
      end

      its (:status) {should == :done}

    end

    context "not in_progress booking" do

      subject do
        booking = BookingDataSystem::Booking.create(booking_offline)
        booking.should_not_receive(:update)
        booking.return_item
      end

      its (:status) {should == :pending_confirmation}

    end

  end  

  describe "#cancel" do

    context "not cancelled booking" do
    
      subject do
        booking = BookingDataSystem::Booking.create(booking_offline)
        booking.cancel
      end

      its (:status) {should == :cancelled}

    end

    context "cancelled booking" do

      subject do
        booking = BookingDataSystem::Booking.create(booking_offline.merge(:status => :cancelled))
        booking.should_not_receive(:update)
        booking.return_item
      end

      its (:status) {should == :cancelled}

    end

  end 

end