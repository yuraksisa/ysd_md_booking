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

				before :create do
					self.calculate_renting_days
					self.calculate_services
					self.free_access_id = Digest::MD5.hexdigest("#{rand}#{date_from.to_time.iso8601}#{date_to.to_time.iso8601}#{rand}")
				end

				# ----------------------------------------------------------------------------------

				#
				# Change selection data : date from/to, pickup/return place
				#
				def change_selection_data(date_from, time_from, date_to, time_to,
																	pickup_place, return_place,
																	number_of_adults, number_of_children)

					transaction do
					  self.date_from = date_from
						self.time_from = time_from
						self.date_to = date_to
						self.time_to = time_to
						self.pickup_place = pickup_place
						self.return_place = return_place
						self.number_of_adults = number_of_adults
						self.number_of_children = number_of_children
						self.calculate_renting_days
					  self.save
						# Recalculate items
						self.items.each do |sc_item|
							product = RentingSearch.search(date_from, date_to, self.days, sc_item.item_id)
							sc_item.update_item_cost(product.base_price, product.price, product.deposit)
						end
						# Recalcute extras
						self.extras.each do |sc_extra|
							extra = RentingExtraSearch.search(date_from, date_to, self.days, sc_extra.extra_id)
							sc_extra.update_extra_cost(extra.unit_price)
						end
						# Recalculate extra services
						self.calculate_services
					end

				end

				#
				# Calculate services (time to/from, pickup/return place, ...)
				#
				def calculate_services
					# calculate_time_from_to_cost
					# pickup_up_return_place_cost
					# calculate_driver_age_cost
				end

				# -----------------------------------------------------------------------------------

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
					  elsif product = RentingSearch.search(date_from, date_to, days, product_code)
						  add_item(product.code, product.name, quantity,
										 product.base_price, product.price, product.deposit)
						end
					else
						product = RentingSearch.search(date_from, date_to, days, product_code)
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

        protected

				#
				# Calculate the renting days (depending on the cadence hours)
				#
				def calculate_renting_days
					cadence_hours = SystemConfiguration::Variable.get_value('booking.hours_cadence',2).to_i
					self.days = (self.date_to - self.date_from).to_i
					self.date_to_price_calculation = self.date_to
					begin
						_t_from = DateTime.strptime(self.time_from,"%H:%M")
						_t_to = DateTime.strptime(self.time_to,"%H:%M")
						if _t_to > _t_from
							hours_of_difference = (_t_to - _t_from).to_f.modulo(1) * 24
							if hours_of_difference > cadence_hours
								self.days += 1
								self.date_to_price_calculation += 1
							end
						end
					rescue
						p "Time from or time to are not valid #{self.time_from} #{self.time_from}"
					end
				end

				#
				# Calculate time from/to cost
				#
				def calculate_time_from_to_cost

					if (pickup_return_timetable_id = SystemConfiguration::Variable.get_value('booking.pickup_return_timetable',0).to_i)
						pickup_return_timetable = (pickup_return_timetable_id > 0) ? ::Yito::Model::Calendar::Timetable.get(pickup_return_timetable_id) : nil
						# pickup / return price
						pickup_return_timetable_out_price = SystemConfiguration::Variable.get_value('booking.pickup_return_timetable_out_price', 0).to_i
						if pickup_return_timetable_out_price > 0

						end
					end

				end

				#
				# Calculate pickup/return place cost
				#
				def pickup_up_return_place_cost
					if (pickup_return_places_id = SystemConfiguration::Variable.get_value('booking.pickup_return_place',0).to_i) > 0
					  pickup_return_place = (pickup_return_places_id > 0) ? PickupReturnPlaceDefinition.get() : PickupReturnPlaceDefinition.first
					end
				end


				#
				# Calculate driver age cost*
				#
				def calculate_driver_age_cost

				end

      end
    end
  end
end        