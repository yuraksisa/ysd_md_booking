FactoryBot.define do
  
  #
  # Booking line resource
  #
  factory(:booking_line_resource, class: BookingDataSystem::BookingLineResource) do
       booking_line
  end	

  #
  # Booking line
  #
  factory(:booking_line, class: BookingDataSystem::BookingLine) do
       item_id { 'A' }
       item_description { 'CLASE A' }
       item_unit_cost_base { 30 }
       item_unit_cost { 30 }
       quantity { 1 }
       item_cost { 30 }
       booking
       factory(:booking_line_with_one_line_resource) do
	       after :create do |booking_line|
	       	create_list(:booking_line_resource, 1, booking_line: booking_line)
	       end	
       end
  end 	

  #
  # Booking extra
  #
  factory(:booking_extra, class: BookingDataSystem::BookingExtra) do
       extra_id { 'silla' }
       extra_description { 'silla description' }
       extra_cost { 20 }
       extra_unit_cost { 10 }
       quantity { 1 }
       booking
  end

  #
  # Standard booking
  #
  factory(:booking, class: BookingDataSystem::Booking) do
	    date_from { Time.utc(2019, 3, 1).to_s }
	    time_from { '10:00' }
	    pickup_place { 'Amsterdam Airport' }
	  	date_to { Time.utc(2019, 3, 3).to_s }
	    time_to { '10:00' }
	    return_place { 'Amsterdam Airport' }
	    date_to_price_calculation { Time.utc(2019, 3, 3).to_s }
	    days { 2 }
	  	item_cost { 30 }
	  	extras_cost { 20 }
	  	total_cost { 50 }
	    total_paid { 0 }
	    total_pending { 50 }
	    status { :pending_confirmation }
	    payment_status {  :none }        
	    payment { 'deposit' }
	  	payment_method_id { 'cecabank' }
	  	customer_name { 'Mr. John' }
	  	customer_surname { 'Smith' }
	  	customer_email { 'john.smith@test.com' }
	  	customer_phone { '935551010' }
	  	customer_mobile_phone { '666101010' }
	    customer_language { 'en' }
	  	comments { 'Comments' }
	  	# Inhreited with one line - one resource - one extra
	  	factory(:booking_with_one_line) do
		  	after :create do |booking| 
	          create_list(:booking_line, 1, booking: booking)
	          create_list(:booking_extra, 1, booking: booking)
		    end		
	    end
  end


end  