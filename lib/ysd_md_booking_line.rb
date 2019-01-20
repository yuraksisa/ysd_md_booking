require 'data_mapper' unless defined?DataMapper

module BookingDataSystem
  # 
  # Represent a booking line with a item and a quantity
  #
  class BookingLine
     include DataMapper::Resource
     storage_names[:default] = 'bookds_bookings_lines' 
 
     property :id, Serial
     property :item_id, String, :length => 20, :required => true
     property :item_description, String, :length => 256
     property :item_description_customer_translation, String, length: 256
     property :optional, String, :length => 40
     property :item_unit_cost_base, Decimal, :precision => 10, :scale => 2, :default => 0
     property :item_unit_cost, Decimal, :precision => 10, :scale => 2, :default => 0
     property :item_cost, Decimal, :precision => 10, :scale => 2, :default => 0
     property :quantity, Integer
     property :product_deposit_unit_cost, Decimal, :precision => 10, :scale => 2, :default => 0
     property :product_deposit_cost, Decimal, :precision => 10, :scale => 2, :default => 0
     property :category_supplement_1_unit_cost, Decimal, scale: 2, precision: 10, default: 0     
     property :category_supplement_1_cost, Decimal, scale: 2, precision: 10, default: 0     
     property :category_supplement_2_unit_cost, Decimal, scale: 2, precision: 10, default: 0     
     property :category_supplement_2_cost, Decimal, scale: 2, precision: 10, default: 0     
     property :category_supplement_3_unit_cost, Decimal, scale: 2, precision: 10, default: 0     
     property :category_supplement_3_cost, Decimal, scale: 2, precision: 10, default: 0     

     belongs_to :booking, 'Booking', :child_key => [:booking_id]
     has n, :booking_line_resources, 'BookingLineResource', :constraint => :destroy 

     # Item supplier
     belongs_to :supplier, 'Yito::Model::Suppliers::Supplier', child_key: [:supplier_id], parent_id: [:id], required: false


     # =============================== Instance methods ==================================================

     #
     # Exporting to json
     #
     def as_json(options={})

       if options.has_key?(:only)
         super(options)
       else
         relationships = options[:relationships] || {}
         relationships.store(:booking_line_resources, {})
         super(options.merge({:relationships => relationships}))
       end

     end

     # --------------------------- Reservation items management -----------------------------------------

     #
     # Change booking line item
     #
     # == Parameters::
     #
     # new_item_id:: New item id
     # price_modification:: Price modification 'update' or 'hold'
     # assignation_review:: Assignation 'hold' or 'update'
     #
     def change_item(new_item_id, 
                     price_modification='update', 
                     assignation_review='hold')

       old_item_id = self.item_id
       
       if new_item_id && new_item_id != self.item_id
        if product = ::Yito::Model::Booking::BookingCategory.get(new_item_id)

           product_customer_translation = product.translate(booking.customer_language)
           item_description = product.name
           item_description_customer_translation = (product_customer_translation.nil? ? product.name : product_customer_translation.name)
           
           old_price = new_price = self.item_unit_cost
           old_product_deposit = new_product_deposit = self.product_deposit_unit_cost
           old_product_supplement_1_unit_cost = new_product_supplement_1_unit_cost = self.category_supplement_1_unit_cost
           old_product_supplement_2_unit_cost = new_product_supplement_2_unit_cost = self.category_supplement_2_unit_cost
           old_product_supplement_3_unit_cost = new_product_supplement_3_unit_cost = self.category_supplement_3_unit_cost

           item_cost_increment = 0
           deposit_cost_increment = 0
           product_supplement_1_unit_cost_increment = 0
           product_supplement_2_unit_cost_increment = 0
           product_supplement_3_unit_cost_increment = 0

           if price_modification == 'update'
             new_price = product.unit_price(booking.date_from, booking.days, nil, self.booking.sales_channel_code).round(0) # Make sure no decimals in price
             ## Apply promotion code and offers
             rates_promotion_code = if self.booking and !self.booking.promotion_code.nil?
                                      ::Yito::Model::Rates::PromotionCode.first(promotion_code: booking.promotion_code)
                                    else
                                      nil
                                    end
             if self.booking
               discount = ::Yito::Model::Booking::BookingCategory.discount(new_price, new_item_id, self.booking.date_from, self.booking.date_to, rates_promotion_code)
               new_price = (new_price - discount).round(0) if discount > 0
             end
             ## End apply offers
             ## Category supplements
             product_supplement_1_unit_cost = product.category_supplement_1_cost || 0
             product_supplement_2_unit_cost = product.category_supplement_2_cost || 0
             product_supplement_3_unit_cost = product.category_supplement_3_cost || 0 
             if self.booking.sales_channel_code
               if bcsc = Yito::Model::Booking::BookingCategoriesSalesChannel.first(conditions: {'sales_channel.code': self.booking.sales_channel_code, booking_category_code: product.code })
                  product_supplement_1_unit_cost = bcsc.category_supplement_1_cost || 0
                  product_supplement_2_unit_cost = bcsc.category_supplement_2_cost || 0
                  product_supplement_3_unit_cost = bcsc.category_supplement_3_cost || 0
               end 
             end 
             ## End of category supplements             
             new_product_deposit = product.deposit
             new_product_supplement_1_unit_cost = product_supplement_1_unit_cost
             new_product_supplement_2_unit_cost = product_supplement_2_unit_cost
             new_product_supplement_3_unit_cost = product_supplement_3_unit_cost

             item_cost_increment = new_price - old_price
             deposit_cost_increment = new_product_deposit - old_product_deposit
             product_supplement_1_unit_cost_increment = new_product_supplement_1_unit_cost - old_product_supplement_1_unit_cost
             product_supplement_2_unit_cost_increment = new_product_supplement_2_unit_cost - old_product_supplement_2_unit_cost
             product_supplement_3_unit_cost_increment = new_product_supplement_3_unit_cost - old_product_supplement_3_unit_cost
           end

           # Update the booking line and the booking
           transaction do
             # Update booking line
             self.item_id = new_item_id
             self.item_description = item_description
             self.item_description_customer_translation = item_description_customer_translation
             unless item_cost_increment == 0
               self.item_unit_cost += item_cost_increment
               self.item_cost = self.item_unit_cost * self.quantity
             end
             unless deposit_cost_increment == 0
               self.product_deposit_unit_cost += deposit_cost_increment
               self.product_deposit_cost = self.product_deposit_unit_cost * self.quantity
             end
             unless product_supplement_1_unit_cost_increment == 0
               self.category_supplement_1_unit_cost += product_supplement_1_unit_cost_increment
               self.category_supplement_1_cost = self.category_supplement_1_unit_cost * self.quantity
             end
             unless product_supplement_2_unit_cost_increment == 0
               self.category_supplement_2_unit_cost += product_supplement_2_unit_cost_increment
               self.category_supplement_2_cost = self.category_supplement_2_unit_cost * self.quantity
             end 
             unless product_supplement_3_unit_cost_increment == 0
               self.category_supplement_3_unit_cost += product_supplement_3_unit_cost_increment
               self.category_supplement_3_cost = self.category_supplement_3_unit_cost * self.quantity
             end                           
             self.save

             # Update booking line resources : Clear or assign new resource
             if assignation_review == 'update'
               # Get the available stock
               stock_detail, category_occupation = BookingDataSystem::Booking.categories_availability(self.booking.rental_location_code,
                                                                                                      self.booking.date_from,
                                                                                                      self.booking.time_from,
                                                                                                      self.booking.date_to,
                                                                                                      self.booking.time_to,
                                                                                                      new_item_id,
                                                                                                      {
                                                                                                        origin: 'booking',
                                                                                                        id: self.booking.id
                                                                                                      })
               # Process all the line resources
               self.booking_line_resources.each do |booking_line_resource|
                  old_booking_item_reference = booking_line_resource.booking_item_reference
                  p "assign_available_stock -- OLD Reference: #{old_booking_item_reference} -- category #{new_item_id} -- available_assignable: #{category_occupation[self.item_id][:available_assignable_stock].inspect}"

                  # Get the first free resource
                  new_booking_item_reference = category_occupation[self.item_id][:available_assignable_stock].first

                  if !new_booking_item_reference.nil? # Assign the resource
                    booking_line_resource.assign_resource(new_booking_item_reference)
                    category_occupation[self.item_id][:available_assignable_stock].delete_at(0)
                  else # Clear the assignation if there is not avaialable assignable resource
                    booking_line_resource.clear_assignation unless old_booking_item_reference.nil?
                  end

               end
             end

             # Update booking
             if item_cost_increment != 0 or 
                deposit_cost_increment != 0 or
                product_supplement_1_unit_cost_increment != 0 or
                product_supplement_2_unit_cost_increment != 0 or
                product_supplement_3_unit_cost_increment != 0
               booking.item_cost += (item_cost_increment * self.quantity)
               booking.product_deposit_cost += (deposit_cost_increment * self.quantity)
               booking.category_supplement_1_cost += (product_supplement_1_unit_cost_increment * self.quantity)
               booking.category_supplement_2_cost += (product_supplement_2_unit_cost_increment * self.quantity)
               booking.category_supplement_3_cost += (product_supplement_3_unit_cost_increment * self.quantity)
               booking.calculate_cost(false, false)
               booking.save
             end

             # Create newsfeed
             ::Yito::Model::Newsfeed::Newsfeed.create(category: 'booking',
                                            action: 'change_item',
                                            identifier: self.booking.id.to_s,
                                            description: BookingDataSystem.r18n.t.booking_news_feed.changed_item(new_item_id, self.id, old_item_id),
                                            attributes_updated: {item_id: new_item_id,
                                                                 booking_item_cost: booking.item_cost,
                                                                 booking_product_deposit_cost: booking.product_deposit_cost,
                                                                 booking_category_supplement_1_cost: booking.category_supplement_1_cost,
                                                                 booking_category_supplement_2_cost: booking.category_supplement_2_cost,
                                                                 booking_category_supplement_3_cost: booking.category_supplement_3_cost,
                                                                 booking_total_cost: booking.total_cost,
                                                                 booking_total_pending: booking.total_pending}.merge({booking: booking.newsfeed_summary}).to_json)
             booking.reload
           end
         end
       end
     end

     #
     # Update booking line quantity
     #
     # == Parameters::
     #
     # new_quantity:: New quantity
     #
     def update_quantity(new_quantity)

       if product = ::Yito::Model::Booking::BookingCategory.get(self.item_id)
         old_quantity = self.quantity
         old_booking_line_item_cost = self.item_cost
         old_booking_line_product_deposit_cost = self.product_deposit_cost
         old_product_supplement_1_cost = self.category_supplement_1_cost
         old_product_supplement_2_cost = self.category_supplement_2_cost
         old_product_supplement_3_cost = self.category_supplement_3_cost
         # Process
         transaction do
           self.quantity = new_quantity
           self.item_cost = self.item_unit_cost * new_quantity
           self.product_deposit_cost = self.product_deposit_unit_cost * new_quantity
           self.category_supplement_1_cost = self.category_supplement_1_unit_cost * new_quantity
           self.category_supplement_2_cost = self.category_supplement_2_unit_cost * new_quantity
           self.category_supplement_3_cost = self.category_supplement_3_unit_cost * new_quantity 
           self.save
           # Add or remove booking line resources
           if new_quantity < old_quantity
             (new_quantity..(old_quantity-1)).each do |resource_number|
               self.booking_line_resources[new_quantity].destroy unless self.booking_line_resources[new_quantity].nil?
             end
           elsif new_quantity > old_quantity
             (old_quantity..(new_quantity-1)).each do |resource_number|
               booking_line_resource = BookingDataSystem::BookingLineResource.new
               booking_line_resource.booking_line = self
               booking_line_resource.save
             end
           end
           # Update the booking (cost)
           item_cost_increment = self.item_cost - old_booking_line_item_cost
           product_deposit_cost_increment = self.product_deposit_cost - old_booking_line_product_deposit_cost
           product_supplement_1_cost_increment = self.category_supplement_1_cost - old_product_supplement_1_cost
           product_supplement_2_cost_increment = self.category_supplement_2_cost - old_product_supplement_2_cost
           product_supplement_3_cost_increment = self.category_supplement_3_cost - old_product_supplement_3_cost
           booking.item_cost += item_cost_increment
           booking.product_deposit_cost += product_deposit_cost_increment
           booking.category_supplement_1_cost += product_supplement_1_cost_increment
           booking.category_supplement_2_cost += product_supplement_2_cost_increment
           booking.category_supplement_3_cost += product_supplement_3_cost_increment
           booking.calculate_cost(false, false)
           booking.save
           # Assign available stock         
           if booking.status == :pending_confirmation 
             if booking.created_by_manager 
               booking.assign_available_stock if SystemConfiguration::Variable.get_value('booking.assignation.automatic_resource_assignation_on_backoffice_request').to_bool
             else
               booking.assign_available_stock if SystemConfiguration::Variable.get_value('booking.assignation.automatic_resource_assignation_on_web_request').to_bool
             end
           elsif booking.status == :confirmed   
             if SystemConfiguration::Variable.get_value('booking.assignation.automatic_resource_assignation', 'false').to_bool
               booking.assign_available_stock
             end
           end          
           # Create newsfeed
           ::Yito::Model::Newsfeed::Newsfeed.create(category: 'booking',
                                          action: 'updated_item_quantity',
                                          identifier: self.booking.id.to_s,
                                          description: BookingDataSystem.r18n.t.booking_news_feed.updated_item_quantity(new_quantity, self.item_id, old_quantity),
                                          attributes_updated: {quantity: new_quantity,
                                                               booking_item_cost: booking.item_cost,
                                                               booking_product_deposit_cost: booking.product_deposit_cost,
                                                               booking_category_supplement_1_cost: booking.category_supplement_1_cost,
                                                               booking_category_supplement_2_cost: booking.category_supplement_2_cost,
                                                               booking_category_supplement_3_cost: booking.category_supplement_3_cost,                                                               
                                                               booking_total_cost: booking.total_cost,
                                                               booking_total_pending: booking.total_pending
                                                               }.merge({booking: booking.newsfeed_summary}).to_json)
         end
         booking.reload
       end

     end

     #
     # Update item cost
     #
     # == Parameters::
     #
     # new_item_unit_cost:: New item cost
     #
     def update_item_cost(new_item_unit_cost)

       if product = ::Yito::Model::Booking::BookingCategory.get(self.item_id)
         old_booking_line_item_cost = self.item_cost
         self.transaction do
           self.item_unit_cost = new_item_unit_cost
           self.item_cost = self.item_unit_cost * self.quantity
           self.save
           # Update the booking (cost)
           item_cost_increment = self.item_cost - old_booking_line_item_cost
           booking.item_cost += item_cost_increment
           booking.calculate_cost(false, false)
           booking.save
           # Create newsfeed
           ::Yito::Model::Newsfeed::Newsfeed.create(category: 'booking',
                                          action: 'updated_item_cost',
                                          identifier: self.booking.id.to_s,
                                          description: BookingDataSystem.r18n.t.booking_news_feed.updated_item_cost("%.2f" % new_item_unit_cost, self.item_id, "%.2f" % old_booking_line_item_cost),
                                          attributes_updated: {item_unit_cost: new_item_unit_cost}.merge({booking: booking.newsfeed_summary}).to_json)
         end
         booking.reload
       end

     end

     #
     # Update item deposit
     #
     # == Parameters
     #
     # new_item_deposit:: New item deposit
     #
     def update_item_deposit(new_item_deposit)

       old_booking_line_product_deposit_cost = self.product_deposit_cost
       self.transaction do
         # Update the booking line
         self.product_deposit_unit_cost = new_item_deposit
         self.product_deposit_cost = new_item_deposit * self.quantity
         self.save
         # Update the booking (cost)
         deposit_cost_increment = self.product_deposit_cost - old_booking_line_product_deposit_cost
         booking.product_deposit_cost += deposit_cost_increment
         booking.calculate_cost(false, false)
         booking.save
         # Create newsfeed
         ::Yito::Model::Newsfeed::Newsfeed.create(category: 'booking',
                                        action: 'updated_item_deposit',
                                        identifier: self.booking.id.to_s,
                                        description: BookingDataSystem.r18n.t.booking_news_feed.updated_item_deposit("%.2f" % new_item_deposit, self.item_id, "%.2f" % old_booking_line_product_deposit_cost),
                                        attributes_updated: {product_deposit_unit_cost: new_item_deposit}.merge({booking: booking.newsfeed_summary}).to_json)
       end
       booking.reload

     end

  end
end