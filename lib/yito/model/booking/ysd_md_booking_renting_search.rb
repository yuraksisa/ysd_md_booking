module Yito
  module Model
  	module Booking
			#
			# Search products, prices and availability
			#
  	  class RentingSearch	
  		 attr_accessor :code, :name, :short_description, :description, :photo, :full_photo,
  		 			   :base_price, :price, :deposit, 
  		 			   :availability, :stock, :busy, :payment_availibility

  		 def initialize(code, name, short_description, description,
  		 	              photo, full_photo,
  		 				        base_price=0, price=0, deposit=0,
  		 				        availability=false,stock=0, busy=0, payment_availibility=false, full_information=false)
  		   @code = code
  		   @name = name
  		   @short_description = short_description
  		   @description = description
  		   @photo = photo
  		   @full_photo = full_photo
  		   @base_price = base_price
  		   @price = price
  		   @deposit = deposit
  		   @availability = availability
  		   @stock = stock
  		   @busy = busy
  		   @payment_availibility = payment_availibility
				 @full_information = full_information
  		 end

  		 def as_json(options={})

  		 	   result = {
					  code: @code,
  		 	   	name: @name,
  		 		  short_description: @short_description,
  		 		  description: @description,
  		 		  photo: @photo,
  		 		  full_photo: @full_photo,
  		 		  base_price: @base_price,
  		 		  price: @price,
  		 		  deposit: @deposit,
  		 		  availability: @availability,
  		 		  payment_availibility: @payment_availibility
					 }

					 result.merge!(stock: @stock, busy: @busy) if @full_information

				   result

  		 end

  		 def to_json(*options)
       	   as_json(*options).to_json(*options)
    	 end

  		 #
  		 # Search products, price and availability
  		 #
  		 def self.search(from, to, days, full_information=false, product_code=nil)

				 domain = SystemConfiguration::Variable.get_value('site.domain')

  		   result = []

  		   # Check the 'real' occupation
         occupation = BookingDataSystem::Booking.occupation(from, to).map do |item|
                 			  {item_id: item.item_id, stock: item.stock, busy: item.busy}
                		  end

         occupation_hash = occupation.inject({}) do |result,item|
           result.store(item[:item_id], item.select {|key,value| key != :item_id})
           result
         end

         # Check the calendar
  		   categories_available = Availability.instance.categories_available(from, to)
  		   categories_payment_enabled = Availability.instance.categories_payment_enabled(from, to)

  		   # General discounts (for range of dates)
  		   general_discount = ::Yito::Model::Rates::Discount.active(Date.today).first

  		   # Query for products
  		   prod_attributes = [:code, :name, :short_description, :description,
  		   					  :stock_control, :stock, :album_id, :deposit]
  		   conditions = {active: true, web_public: true}
  		   conditions.store(:code, product_code) unless product_code.nil?

  		   result = ::Yito::Model::Booking::BookingCategory.all(fields: prod_attributes, 
  		   			   conditions: conditions, 
  		   			   order: [:code]).map do |item| 
  		   	           
  		   	           # Get the photos
  		   	           photo = item.album ? item.album.thumbnail_medium_url : nil
  		   	           full_photo = item.album ? item.album.image_url : nil

  		   	           # Get the price
  		   	           product_price = item.unit_price(from, days)
  		   	           
  		   	           # Apply offers and discounts
  		   	           discount = 0
  		   	           if general_discount
  		   	              case general_discount.discount_type 
  		   	                when :percentage
  		   	                	discount = product_price * (general_discount.value / 100)
  		   	           	    when :amount
  		   	           	        discount = general_discount.value 
  		   	           	  end	
	           		     end

  		   	           base_price = product_price.round(0) # Make sure no decimals in prices
  		   	           price = (product_price - discount).round(0) # Make sure no decimal in prices
  		   	           deposit = item.deposit
  		   	           
  		   	           # Get the availability
  		   	           stock = occupation_hash.has_key?(item.code) ? occupation_hash[item.code][:stock] : 0
  		   	           busy = occupation_hash.has_key?(item.code) ? occupation_hash[item.code][:busy] : 0
  		   	           available = categories_available.include?(item.code) # Calendar lock
										 available = available && (stock > busy) if item.stock_control # Stock
  		   	           payment_available = categories_payment_enabled.include?(item.code)

  		   	           RentingSearch.new(item.code, item.name, item.short_description, item.description, 
  		   	           	         photo.match(/^https?:/) ? photo : File.join(domain, photo),
															 full_photo.match(/^https?:/) ? full_photo : File.join(domain, full_photo),
  		   	           					 base_price, price, deposit, 
  		   	           					 available, stock, busy, payment_available, full_information)
  		   	        end
  		   
  		   return product_code.nil? ? result : result.first	        

  		 end

 	  end
 	end
  end
end