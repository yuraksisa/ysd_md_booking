require 'spec_helper'

#
# Test the availability for categories stock (standard) with no storage
#
# The standard model for a Rent a Car solution
#
# Uses data from booking_stock_by_categories_factories.rb
#
describe 'Booking Availability for categorized Rent a car + No storage + Stock control' do 

    #
    # Full availability : there are no reservation in the period
    #
    context "Full availability - stock control" do

      before do
      	# Create the business
        create(:booking_family_rent_a_car)
        create(:settings_variable_item_family_rent_a_car)
        # Create the categories and the stock
        booking_category_a = create(:booking_category_a, stock_control: true)
        booking_category_b = create(:booking_category_b, stock_control: true)
        create(:booking_item_1111AAA_category_a, category: booking_category_a)
        create(:booking_item_2222AAA_category_a, category: booking_category_a)
        create(:booking_item_3333AAA_category_a, category: booking_category_b)
        create(:booking_item_1111BBB_category_b, category: booking_category_b)
        create(:booking_item_2222BBB_category_b, category: booking_category_b)
      end	

      subject(:search) do
        Yito::Model::Booking::BookingCategory.search(nil, Date.new(2019,03,01), '10:00', Date.new(2019,03,03), '10:00', 2)
      end	

      it do
      	#
      	# Returns an array of Yito::Model::Booking::RentingSearch with code, name, stock, busy, available
      	#
        expect(search.size).to be 2 
        expect(search.first.stock).to be 2
        expect(search.first.busy).to be 0
        expect(search.first.available).to be 2 
        expect(search.last.stock).to be 3
        expect(search.last.busy).to be 0
        expect(search.last.available).to be 3         
      end 

    end	

    #
    # Full availability : there are no reservation in the period
    #
    context "Reservations in the period - stock control" do

      before do
      	# Create the business
        create(:booking_family_rent_a_car)
        create(:settings_variable_item_family_rent_a_car)      	
        # Create the categories and the stock
        booking_category_a = create(:booking_category_a, stock_control: true)
        booking_category_b = create(:booking_category_b, stock_control: true)
        create(:booking_item_1111AAA_category_a, category: booking_category_a)
        create(:booking_item_2222AAA_category_a, category: booking_category_a)
        create(:booking_item_3333AAA_category_a, category: booking_category_b)
        create(:booking_item_1111BBB_category_b, category: booking_category_b)
        create(:booking_item_2222BBB_category_b, category: booking_category_b)
        # Create a reservation that is included in the search range
        booking_1_line = build(:booking_line, item_id: booking_category_a.code, quantity: 1)
        booking_1_line_resource = build(:booking_line_resource, booking_line: booking_1_line)
        booking_1_line.booking_line_resources << booking_1_line_resource
        booking_1 = create(:booking, 
         	             date_from: Date.new(2019, 03, 01), 
         	             time_from: '11:00', 
        	             date_to: Date.new(2019, 03, 02), 
         	             time_to: '10:00',
         	             booking_lines: [booking_1_line])
        # Create a reservation that is not included in the search range
        booking_2_line = build(:booking_line, item_id: booking_category_a.code, quantity: 1)
        booking_2_line_resource = build(:booking_line_resource, booking_line: booking_2_line)
        booking_2_line.booking_line_resources << booking_2_line_resource
        booking_2 = create(:booking_with_one_line, 
         	               date_from: Date.new(2019, 05, 01), 
         	               time_from: '11:00', 
         	               date_to: Date.new(2019, 05, 02), 
         	               time_to: '10:00',
         	               booking_lines: [booking_2_line])        
      end	

      subject(:search) do
        Yito::Model::Booking::BookingCategory.search(nil, Date.new(2019,03,01), '10:00', Date.new(2019,03,03), '10:00', 2)
      end	

      it do
      	#
      	# Returns an array of Yito::Model::Booking::RentingSearch with code, name, stock, busy, available
      	#
        expect(search.size).to be 2 
        expect(search.first.stock).to be 2
        expect(search.first.busy).to be 1
        expect(search.first.available).to be 1 
        expect(search.last.stock).to be 3
        expect(search.last.busy).to be 0
        expect(search.last.available).to be 3         
      end 

    end	    

end