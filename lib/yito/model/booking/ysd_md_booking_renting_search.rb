module Yito
  module Model
  	module Booking
   	  #
	  # Search products, prices and availability
	  #
  	  class RentingSearch	

  		 attr_accessor :code, :name, :short_description, :description, :stock_control, 
  		 			   :photo, :full_photo,
  		 			   :base_price, :price, :deposit, 
  		 			   :category_supplement_1_cost, :category_supplement_2_cost,
  		 			   :category_supplement_3_cost,
  		 			   :availability, :stock, :busy, :available, :payment_availibility, 
  		 			   :include_stock, :resources

  		 def initialize(code, name, short_description, description, stock_control,
  		 	            photo, full_photo, base_price=0, price=0, deposit=0,
  		 	            category_supplement_1_cost=0, category_supplement_2_cost=0,
  		 	            category_supplement_3_cost=0,
  		 				availability=false, stock=0, busy=0, available=0, 
						payment_availibility=false, full_information=false,
						include_stock=false, resources=nil)
  		   @code = code
  		   @name = name
  		   @short_description = short_description
  		   @description = description
		   @stock_control = stock_control
  		   @photo = photo
  		   @full_photo = full_photo
  		   @base_price = base_price
  		   @price = price
  		   @deposit = deposit
  		   @category_supplement_1_cost = category_supplement_1_cost
  		   @category_supplement_2_cost = category_supplement_2_cost
  		   @category_supplement_3_cost = category_supplement_3_cost  		   
  		   @availability = availability
  		   @stock = stock
  		   @busy = busy
		   @available = available
  		   @payment_availibility = payment_availibility
		   @full_information = full_information
		   @include_stock = include_stock
		   @resources = resources
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
				  available: @available,
  		 		  payment_availibility: @payment_availibility,
  		 		  category_supplement_1_cost: @category_supplement_1_cost,
  		 		  category_supplement_2_cost: @category_supplement_2_cost,
  		 		  category_supplement_3_cost: @category_supplement_3_cost
			}

			result.merge!(stock: @stock, busy: @busy) if @full_information
			result.merge!(resources: @resources) if @include_stock

			result

  		 end

  		 def to_json(*options)
       	   as_json(*options).to_json(*options)
    	 end

  		 #
  		 # Search products, price and availability
  		 #
		 # == Parameters:
         # rental_location_code::
         #   The rental location code  		 
		 # date_from::
		 #   The reservation starting date
		 # time_from::
		 #   The reservation starting time
		 # date_to::
		 #   The reservation ending date
		 # time_to::
		 #   The reservation ending time
		 # days::
		 #   The reservation number of days
		 # options::
		 #   A hash with some options
		 #   :locale -> The locale for the translations
		 #   :full_information -> Shows the stock information (total and available)
		 #   :product_code -> The product code (for a specific category search)
		 #   :web_public -> Include only web_public categories
		 #   :sales_channel_code -> The sales channel code (nil for default)
		 #   :promotion_code -> The promotion code
		 #   :apply_promotion_code -> Apply the promotion code
		 #   :include_stock -> Include the stock references in the result (if we want to known the free resources)
		 #   :ignore_urge -> It's a hash with two keys, origin and id. It allows to avoid the pre-assignation of the
		 #              pending reservation. It's used when trying to assign resources to this reservation
		 # == Returns:
		 # An array of RentingSearch items
		 #
  		 def self.search(rental_location_code, date_from, time_from, date_to, time_to, days, options={})

             product_family = ::Yito::Model::Booking::ProductFamily.get(SystemConfiguration::Variable.get_value('booking.item_family'))

             # Check if the search is by resource or category
             search_by_resource = false
             if product_family and product_family.product_type == :resource 
                search_by_resource = true             
             end 			 

			 # Retrieve the options
			 locale = (options.has_key?(:locale) ? options[:locale] : nil)
			 full_information = (options.has_key?(:full_information) ? options[:full_information] : false)
			 product_code = (options.has_key?(:product_code) ? options[:product_code] : nil)
			 web_public = (options.has_key?(:web_public) ? options[:web_public] : false)
			 sales_channel_code = (options.has_key?(:sales_channel_code) ? options[:sales_channel_code] : nil)
			 apply_promotion_code = (options.has_key?(:apply_promotion_code) ? options[:apply_promotion_code] : false)
			 promotion_code = (options.has_key?(:promotion_code) ? options[:promotion_code] : nil)
			 include_stock = (options.has_key?(:include_stock) ? options[:include_stock] : false)
			 ignore_urge = (options.has_key?(:ignore_urge) ? options[:ignore_urge] : nil)

			 # Proceed
			 domain = SystemConfiguration::Variable.get_value('site.domain')

		     result = []

			 # Check the 'real' occupation
	         occupation = BookingDataSystem::Booking.categories_availability_summary(rental_location_code,
	         																		 date_from, time_from,
																					 date_to, time_to,
																					 nil,
																					 ignore_urge, include_stock).map do |item|
					        if include_stock
							  {item_id: item.item_id, stock: item.stock, busy: item.busy, resources: item.resources}
							else
	             			  {item_id: item.item_id, stock: item.stock, busy: item.busy}
							end
	            		  end

	         occupation_hash = occupation.inject({}) do |result,item|
	           result.store(item[:item_id], item.select {|key,value| key != :item_id})
	           result
	         end

	         # Check the calendar
			 categories_available = Availability.instance.categories_available(date_from, date_to)
	  		 categories_payment_enabled = Availability.instance.categories_payment_enabled(date_from, date_to)

			 # Promotional code
			 rates_promotion_code = if apply_promotion_code and promotion_code and !promotion_code.nil?
															  if ::Yito::Model::Rates::PromotionCode.valid_code?(promotion_code, date_from, date_to)
																  ::Yito::Model::Rates::PromotionCode.first(promotion_code: promotion_code)
																else
																	nil
																end
															else
																nil
															end

			 # Query for products
	  		 prod_attributes = [:code, :name, :short_description, :description,
	  		  		            :stock_control, :stock, :album_id, :deposit, 
	  		  		            :category_supplement_1_cost,
	  		  		            :category_supplement_2_cost,
	  		  		            :category_supplement_3_cost,
	  		  		            :price_definition_id]
	  		 conditions = {active: true}
			 conditions.store(:web_public, true) if web_public
			 
			 if product_code.nil? # If configuration is by resource instead take only the selected resources
			   conditions.store(:code, occupation_hash.keys) if search_by_resource	
			 else	
	  		   conditions.store(:code, product_code)
	  		 end
			 
			 conditions.store('sales_channels.code', [sales_channel_code]) unless sales_channel_code.nil?

		     result = ::Yito::Model::Booking::BookingCategory.all(fields: prod_attributes,
		   			      conditions: conditions, order: [:sort_order, :code]).map do |item|
						   # Translate the product
						   item = item.translate(locale) if locale 

	  		   	           # Get the photos
	  		   	           photo = item.album ? item.album.thumbnail_medium_url : nil
	  		   	           full_photo = item.album ? item.album.image_url : nil
											 photo_path = nil
											 if photo
												 photo_path = (photo.match(/^https?:/) ? photo : File.join(domain, photo))
											 end
											 full_photo_path = nil
											 if full_photo
												 full_photo_path = (full_photo.match(/^https?:/) ? full_photo : File.join(domain, full_photo))
											 end

	  		   	           # Get the price
	  		   	           product_price = item.unit_price(date_from, days, nil, sales_channel_code)

						   # Apply promotion code or offers
						   discount = ::Yito::Model::Booking::BookingCategory.discount(product_price, item.code, date_from, date_to, rates_promotion_code)
	  		   	           base_price = product_price.round(0) # Make sure no decimals in prices
	  		   	           price = (product_price - discount).round(0) # Make sure no decimal in prices
	  		   	           deposit = item.deposit
	  		   	           
  		   	           	   category_supplement_1_cost = 0
  		   	           	   category_supplement_2_cost = 0
  		   	           	   category_supplement_3_cost =	0

	  		   	           if sales_channel_code.nil?
	  		   	           	 category_supplement_1_cost = item.category_supplement_1_cost
	  		   	           	 category_supplement_2_cost = item.category_supplement_2_cost
	  		   	           	 category_supplement_3_cost =	item.category_supplement_3_cost	  		   	           	
	  		   	           else	
	  		   	           	 if bc_sc = BookingCategoriesSalesChannel.first(conditions: {'sales_channel.code': sales_channel_code, booking_category_code: item.code })
	  		   	           	   category_supplement_1_cost = bc_sc.category_supplement_1_cost
	  		   	           	   category_supplement_2_cost = bc_sc.category_supplement_2_cost
	  		   	           	   category_supplement_3_cost = bc_sc.category_supplement_3_cost
	  		   	           	 end  	
	  		   	           end	

	  		   	           # Get the availability
	  		   	           stock = occupation_hash.has_key?(item.code) ? occupation_hash[item.code][:stock] : 0
											 resources = occupation_hash.has_key?(item.code) ? occupation_hash[item.code][:resources] : nil
	  		   	           availability = categories_available.include?(item.code) # Calendar lock
											 if item.stock_control # Stock
												 busy = occupation_hash.has_key?(item.code) ? occupation_hash[item.code][:busy] : 0
												 availability = (availability && (stock > busy))
												 available = [(stock - busy), 0].max
											 else # No stock control - [All are available]
												 #busy = 0
												 busy = occupation_hash.has_key?(item.code) ? occupation_hash[item.code][:busy] : 0
												 available = stock
											 end
	  		   	           payment_available = categories_payment_enabled.include?(item.code)

	  		   	           RentingSearch.new(item.code, item.name, item.short_description, item.description, 
											 item.stock_control, photo_path, full_photo_path,
											 base_price, price, deposit,
											 category_supplement_1_cost,
											 category_supplement_2_cost,
											 category_supplement_3_cost,
											 availability, stock, busy, available,
											 payment_available, full_information, include_stock, 
											 resources)
		   	          end

			 return product_code.nil? ? result : result.first
  		 end
	
 	  end
 	end
  end
end