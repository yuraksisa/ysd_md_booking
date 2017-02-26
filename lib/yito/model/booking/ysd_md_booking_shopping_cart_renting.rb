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

     	has n, :extras, 'ShoppingCartExtraRenting', :constraint => :destroy
     	has n, :items, 'ShoppingCartItemRenting', :constraint => :destroy
     	has n, :item_resources, 'ShoppingCartItemResourceRenting', :through => :items


        before :save do |shopping_cart|

				 	 cadence_hours = SystemConfiguration::Variable.get_value('booking.hours_cadence',2).to_i
           shopping_cart.days = (shopping_cart.date_to - shopping_cart.date_from).to_i
					 shopping_cart.date_to_price_calculation = shopping_cart.date_to
					 begin
						 _t_from = DateTime.strptime(shopping_cart.time_from,"%H:%M")
						 _t_to = DateTime.strptime(shopping_cart.time_to,"%H:%M")
						 if _t_to > _t_from
							 hours_of_difference = (_t_to - _t_from).to_f.modulo(1) * 24
							 if hours_of_difference > cadence_hours
								 shopping_cart.days += 1
								 shopping_cart.date_to_price_calculation += 1
							 end
						 end
					 rescue
						 p "Time from or time to are not valid #{shopping_cart.time_from} #{shopping_cart.time_from}"
					 end

           # TODO UPDATE : 
           # time_from_cost, time_to_cost,
           # pickup_place_cost, return_place_cost
           # driver_age_cost
        end


				#
				# Add an item to the shopping cart
				#
				def add_item(item_id, item_description, quantity,
										 item_unit_cost_base, item_unit_cost, product_deposit_unit_cost)

					shopping_cart_item = ShoppingCartItemRenting.new
					shopping_cart_item.shopping_cart = self
					shopping_cart_item.set_item(item_id, item_description, quantity,
																			item_unit_cost_base, item_unit_cost, product_deposit_unit_cost)

				end

        #
        # Set the item to the shopping cart
        #
        def set_item(product_code)

          if product = RentingSearch.search(date_from, date_to, days, product_code)
            if items.size == 0 # Shopping cart empty
              add_item(product.code, product.name, 1,
                       product.base_price, product.price, product.deposit)
            else # Shopping cart contains element
              items.first.set_item(product.code, product.name, 1,
                                 product.base_price, product.price, product.deposit)
						end
					end
  

        end


				#
				# Set an extra to the shopping cart
				#
				def set_extra(extra_code, quantity=1)

					if shopping_cart_extra = extras.select { |extra| extra.extra_id == extra_code }.first
						shopping_cart_extra.update_quantity(quantity) if shopping_cart_extra.quantity != quantity
					elsif extra = RentingExtraSearch.search(date_from, date_to, days, extra_code)
 				  	shopping_cart_extra = ShoppingCartExtraRenting.new
					  shopping_cart_extra.shopping_cart = self
						extras << shopping_cart_extra
					  shopping_cart_extra.set_item(extra.code, extra.name, extra.unit_price, quantity)
					end

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


      end
    end
  end
end        