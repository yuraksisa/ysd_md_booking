module Yito
  module Model
    module Booking
      #
      # Shopping cart (renting)
      #
      class ShoppingCartRenting
        include DataMapper::Resource    	
     	  include BookingDataSystem::BookingGuests
     	  include BookingDataSystem::BookingDriver
     	  include BookingDataSystem::BookingPickupReturn
     	  include BookingDataSystem::BookingFlight

      storage_names[:default] = 'bookds_shopping_cart_renting'
      
      property :id, Serial

     	property :date_from, DateTime, :required => true
     	property :time_from, String, :required => false, :length => 5
     	property :date_to, DateTime, :required => true 
     	property :time_to, String, :required => false, :length => 5
          
     	property :item_cost, Decimal, :scale => 2, :precision => 10, :default => 0
     	property :extras_cost, Decimal, :scale => 2, :precision => 10, :default => 0
     	property :time_from_cost, Decimal, :scale => 2, :precision => 10, :default => 0
     	property :time_to_cost, Decimal, :scale => 2, :precision => 10, :default => 0
     	property :product_deposit_cost, Decimal, :scale => 2, :precision => 10, :default => 0
     	property :total_cost, Decimal, :scale => 2, :precision => 10, :default => 0
	    property :booking_amount, Decimal, :scale => 2, :precision => 10, :default => 0

	    property :date_to_price_calculation, DateTime
    	property :days, Integer

    	property :customer_name, String, :length => 40
     	property :customer_surname, String, :length => 40
     	property :customer_email, String, :length => 40
     	property :customer_phone, String, :length => 15 
     	property :customer_mobile_phone, String, :length => 15
     	property :customer_language, String, :length => 3
     	property :customer_document_id, String, :length => 50

     	property :promotion_code, String, :length => 256
     	property :comments, String, :length => 1024

			property :pay_now, Boolean, :field => 'pay_now', :default => false
			property :payment_method_id, String, :field => 'payment_method_id', :length => 30

	  	property :free_access_id, String, :field => 'free_access_id', :length => 32, :unique_index => :shopping_cart_renting_free_access_id_index

     	has n, :extras, 'ShoppingCartExtraRenting', :constraint => :destroy
     	has n, :items, 'ShoppingCartItemRenting', :constraint => :destroy
     	has n, :item_resources, 'ShoppingCartItemResourceRenting', :through => :items

				#
				# Get a booking by its free access id
				#
				# @parm [String] free access id
				# @return [Booking]
				#
				def self.get_by_free_access_id(free_id)
					first({:free_access_id => free_id})
				end

				#
				# Create a new reservation from a booking
				#
				def update_from_booking(booking)
					self.customer_name = booking.customer_name
					self.customer_surname = booking.customer_surname
					self.customer_email = booking.customer_email
					self.customer_phone = booking.customer_phone
					self.customer_mobile_phone = booking.customer_mobile_phone
					self.customer_language = booking.customer_language
					self.customer_document_id = booking.customer_document_id

					self.driver_name = booking.driver_name
					self.driver_surname = booking.driver_surname
					self.driver_document_id = booking.driver_document_id
					self.driver_document_id_date = booking.driver_document_id_date
					self.driver_document_id_expiration_date = booking.driver_document_id_expiration_date
					self.driver_origin_country = booking.driver_origin_country
					self.driver_date_of_birth = booking.driver_date_of_birth
					self.driver_driving_license_number = booking.driver_driving_license_number
					self.driver_driving_license_date = booking.driver_driving_license_date
					self.driver_driving_license_country = booking.driver_driving_license_country
					self.driver_driving_license_expiration_date = booking.driver_driving_license_expiration_date

					self.additional_driver_1_name = booking.additional_driver_1_name
					self.additional_driver_1_surname = booking.additional_driver_1_surname
					self.additional_driver_1_document_id = booking.additional_driver_1_document_id
					self.additional_driver_1_document_id_date = booking.additional_driver_1_document_id_date
					self.additional_driver_1_document_id_expiration_date = booking.additional_driver_1_document_id_expiration_date
					self.additional_driver_1_origin_country = booking.additional_driver_1_origin_country
					self.additional_driver_1_date_of_birth = booking.additional_driver_1_date_of_birth
					self.additional_driver_1_driving_license_number = booking.additional_driver_1_driving_license_number
					self.additional_driver_1_driving_license_date = booking.additional_driver_1_driving_license_date
					self.additional_driver_1_driving_license_country = booking.additional_driver_1_driving_license_country
					self.additional_driver_1_driving_license_expiration_date = booking.additional_driver_1_driving_license_expiration_date
					self.additional_driver_1_phone = booking.additional_driver_1_phone
					self.additional_driver_1_email = booking.additional_driver_1_email

					self.additional_driver_2_name = booking.additional_driver_2_name
					self.additional_driver_2_surname = booking.additional_driver_2_surname
					self.additional_driver_2_document_id = booking.additional_driver_2_document_id
					self.additional_driver_2_document_id_date = booking.additional_driver_2_document_id_date
					self.additional_driver_2_document_id_expiration_date = booking.additional_driver_2_document_id_expiration_date
					self.additional_driver_2_origin_country = booking.additional_driver_2_origin_country
					self.additional_driver_2_date_of_birth = booking.additional_driver_2_date_of_birth
					self.additional_driver_2_driving_license_number = booking.additional_driver_2_driving_license_number
					self.additional_driver_2_driving_license_date = booking.additional_driver_2_driving_license_date
					self.additional_driver_2_driving_license_country = booking.additional_driver_2_driving_license_country
					self.additional_driver_2_driving_license_expiration_date = booking.additional_driver_2_driving_license_expiration_date
					self.additional_driver_2_phone = booking.additional_driver_2_phone
					self.additional_driver_2_email = booking.additional_driver_2_email
					
					self.additional_driver_3_name = booking.additional_driver_3_name
					self.additional_driver_3_surname = booking.additional_driver_3_surname
					self.additional_driver_3_document_id = booking.additional_driver_3_document_id
					self.additional_driver_3_document_id_date = booking.additional_driver_3_document_id_date
					self.additional_driver_3_document_id_expiration_date = booking.additional_driver_3_document_id_expiration_date
					self.additional_driver_3_origin_country = booking.additional_driver_3_origin_country
					self.additional_driver_3_date_of_birth = booking.additional_driver_3_date_of_birth
					self.additional_driver_3_driving_license_number = booking.additional_driver_3_driving_license_number
					self.additional_driver_3_driving_license_date = booking.additional_driver_3_driving_license_date
					self.additional_driver_3_driving_license_country = booking.additional_driver_3_driving_license_country
					self.additional_driver_3_driving_license_expiration_date = booking.additional_driver_3_driving_license_expiration_date
					self.additional_driver_3_phone = booking.additional_driver_3_phone
					self.additional_driver_3_email = booking.additional_driver_3_email
					
					if self.driver_address.nil?
						self.driver_address = LocationDataSystem::Address.new
					end
					self.driver_address.street = booking.driver_address.street if booking.driver_address
					self.driver_address.number = booking.driver_address.number if booking.driver_address
					self.driver_address.complement = booking.driver_address.complement if booking.driver_address
					self.driver_address.city = booking.driver_address.city if booking.driver_address
					self.driver_address.state = booking.driver_address.state if booking.driver_address
					self.driver_address.country = booking.driver_address.country if booking.driver_address
					self.driver_address.zip = booking.driver_address.zip if booking.driver_address
				end

				before :create do
					self.calculate_supplements
					self.free_access_id = Digest::MD5.hexdigest("#{rand}#{date_from.to_time.iso8601}#{date_to.to_time.iso8601}#{rand}")
				end

				# ----------------------------------------------------------------------------------

				#
				# Change selection data : date from/to, pickup/return place
				#
				def change_selection_data(date_from, time_from, date_to, time_to,
																	pickup_place, return_place,
																	number_of_adults, number_of_children,
				                          driver_under_age)

					transaction do
					  self.date_from = date_from
						self.time_from = time_from
						self.date_to = date_to
						self.time_to = time_to
						self.pickup_place = pickup_place
						self.return_place = return_place
						self.number_of_adults = number_of_adults
						self.number_of_children = number_of_children
						self.driver_under_age = driver_under_age
						self.calculate_supplements
					  self.save

						# Recalculate items
						self.items.each do |sc_item|
							product = RentingSearch.search(date_from, date_to, self.days,  false, sc_item.item_id)
							sc_item.update_item_cost(product.base_price, product.price, product.deposit)
						end
						# Recalcute extras
						self.extras.each do |sc_extra|
							extra = RentingExtraSearch.search(date_from, date_to, self.days, sc_extra.extra_id)
							sc_extra.update_extra_cost(extra.unit_price)
						end

					end

				end

				#
				# Calculate supplements (time to/from, pickup/return place, ...)
				#
				def calculate_supplements

					self.total_cost -= (self.time_from_cost + self.time_to_cost + self.pickup_place_cost +
							                self.return_place_cost + self.driver_age_cost)

					calculator = RentingCalculator.new(self.date_from, self.time_from,
					                                    self.date_to, self.time_to,
					                                   self.pickup_place, self.return_place,
																						 self.driver_date_of_birth, self.driver_under_age)

					self.days = calculator.days
					self.date_to_price_calculation = calculator.date_to_price_calculation
					self.time_from_cost = calculator.time_from_cost
					self.time_to_cost = calculator.time_to_cost
					self.pickup_place_cost = calculator.pickup_place_cost
					self.return_place_cost = calculator.return_place_cost
					self.driver_age = calculator.age
					self.driver_age_cost = calculator.age_cost

					self.total_cost += (self.time_from_cost + self.time_to_cost + self.pickup_place_cost +
							                self.return_place_cost + self.driver_age_cost)

				end

				# -----------------------------------------------------------------------------------

				def clear
					transaction do
						items.destroy
						extras.destroy
						self.time_from_cost = 0
						self.time_to_cost = 0
						self.pickup_place_cost = 0
						self.return_place_cost = 0
						self.driver_age_cost = 0
						self.total_cost = 0
						self.item_cost = 0
						self.extras_cost = 0
						self.product_deposit_cost = 0
						self.booking_amount = 0
						self.customer_name = nil
						self.customer_surname = nil
						self.customer_email = nil
						self.customer_phone = nil
						self.customer_mobile_phone = nil
						self.save
					end
				end
				
				#
				# Add an item to the shopping cart
				#
				def add_item(item_id, item_description, quantity,
										 item_unit_cost_base, item_unit_cost, product_deposit_unit_cost)

					shopping_cart_item = ShoppingCartItemRenting.new
					shopping_cart_item.shopping_cart = self
					self.items << shopping_cart_item
					shopping_cart_item.set_item(item_id, item_description, quantity,
																			item_unit_cost_base, item_unit_cost, product_deposit_unit_cost)

				end

				#
				# Add an extra to the shopping cart
				#
				def add_extra(extra_code, extra_description, quantity, extra_unit_cost)
					shopping_cart_extra = ShoppingCartExtraRenting.new
					shopping_cart_extra.shopping_cart = self
					self.extras << shopping_cart_extra
					shopping_cart_extra.set_item(extra_code, extra_description, extra_unit_cost, quantity)
				end

				#
				# Remove an extra
				#
				def remove_extra(extra_code)

					if shopping_cart_extra = extras.select { |extra|  extra.extra_id == extra_code }.first
						shopping_cart_extra.destroy
						self.reload # To reload the extras
					end

				end

				#
				# Set the item to the shopping cart
				#
				def set_item(product_code, quantity=1, multiple_items=false)

					if multiple_items
  					  # Shopping cart contains item
		  			  if shopping_cart_item = items.select { |item| item.item_id == product_code }.first
				  		shopping_cart_item.update_quantity(quantity) if shopping_cart_item.quantity != quantity
					  # Shopping cart does not contain item
					  else 
					  	if product = RentingSearch.search(date_from, date_to, days, false, product_code)
						  add_item(product.code, product.name, quantity,
								   product.base_price, product.price, product.deposit)
					    end
					  end  
					else
					  product = RentingSearch.search(date_from, date_to, days, false, product_code)
					  # Shopping cart empty
					  if items.size == 0
						add_item(product.code, product.name, quantity,
								 product.base_price, product.price, product.deposit)
					  else
						items.first.set_item(product.code, product.name, quantity,
											 product.base_price, product.price, product.deposit)
					  end
					end

				end

				#
				# Set an extra to the shopping cart
				#
				def set_extra(extra_code, quantity=1)

					# Shopping cart contains extra
					if shopping_cart_extra = extras.select { |extra| extra.extra_id == extra_code }.first
						shopping_cart_extra.update_quantity(quantity) if shopping_cart_extra.quantity != quantity
						# Shopping cart does not contain extra
					elsif extra = RentingExtraSearch.search(date_from, date_to, days, extra_code)
						add_extra(extra.code, extra.name, quantity, extra.unit_price)
					end

				end

      end
    end
  end
end        