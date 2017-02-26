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
     property :optional, String, :length => 40
     property :item_unit_cost_base, Decimal, :precision => 10, :scale => 2, :default => 0
     property :item_unit_cost, Decimal, :precision => 10, :scale => 2, :default => 0
     property :item_cost, Decimal, :precision => 10, :scale => 2, :default => 0
     property :quantity, Integer
     property :product_deposit_unit_cost, Decimal, :precision => 10, :scale => 2, :default => 0
     property :product_deposit_cost, Decimal, :precision => 10, :scale => 2, :default => 0
     belongs_to :booking, 'Booking', :child_key => [:booking_id]
     has n, :booking_line_resources, 'BookingLineResource', :constraint => :destroy 

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
     def change_item(new_item_id, price_modification='update')

       if new_item_id && new_item_id != booking_line.item_id
        if product = ::Yito::Model::Booking::BookingCategory.get(new_item_id)
           booking_deposit = SystemConfiguration::Variable.get_value('booking.deposit', 0).to_i
           item_description = product.name
           old_price = new_price = self.item_unit_cost
           old_product_deposit = new_product_deposit = self.product_deposit_unit_cost
           if price_modification == 'update'
             new_price = product.unit_price(booking.date_from, booking.days).round
             new_product_deposit = product.deposit
           end
           # Update the booking line and the booking
           self.transaction do
             item_cost_increment = new_price - old_price
             deposit_cost_increment = new_product_deposit - old_product_deposit
             total_cost_increment = item_cost_increment + deposit_cost_increment
             # Update booking line
             self.item_id = new_item_id
             self.item_description = item_description
             if item_cost_increment != 0
               self.item_unit_cost += item_cost_increment
               self.item_cost = self.item_unit_cost * self.quantity
             end
             if deposit_cost_increment != 0
               self.product_deposit_unit_cost += deposit_cost_increment
               self.product_deposit_cost = self.product_deposit_unit_cost * self.quantity
             end
             self.save
             # Update booking
             if item_cost_increment > 0 || deposit_cost_increment > 0
               booking.item_cost += item_cost_increment
               booking.product_deposit_cost += deposit_cost_increment
               booking.total_cost += total_cost_increment
               booking.total_pending += total_cost_increment
               booking.booking_amount += (total_cost_increment * booking_deposit / 100).round unless booking_deposit == 0
               booking.save
             end
             booking.reload
           end
         end
       end
     end

     #
     # Update booking line quantity
     #
     def update_quantity(new_quantity)

       if product = ::Yito::Model::Booking::BookingCategory.get(self.item_id)
         booking_deposit = SystemConfiguration::Variable.get_value('booking.deposit', 0).to_i
         product_deposit_cost = product.deposit
         old_quantity = self.quantity
         old_booking_line_item_cost = self.item_cost
         old_booking_line_product_deposit_cost = self.product_deposit_cost
         self.transaction do
           self.quantity = quantity
           self.item_cost = self.item_unit_cost * new_quantity
           self.product_deposit_unit_cost = product_deposit_cost
           self.product_deposit_cost = product_deposit_cost * new_quantity
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
           deposit_cost_increment = self.product_deposit_cost - old_booking_line_product_deposit_cost
           total_cost_increment = item_cost_increment + deposit_cost_increment
           booking.item_cost += item_cost_increment
           booking.product_deposit_cost += deposit_cost_increment
           booking.total_cost += total_cost_increment
           booking.total_pending += total_cost_increment
           booking.booking_amount += (total_cost_increment * booking_deposit / 100).round unless booking_deposit == 0
           booking.save
         end
         booking.reload
       end

     end

     #
     # Update item cost
     #
     def update_item_cost(new_item_unit_cost)

       if product = ::Yito::Model::Booking::BookingCategory.get(booking_line.item_id)
         booking_deposit = SystemConfiguration::Variable.get_value('booking.deposit', 0).to_i
         old_booking_line_item_cost = self.item_cost
         self.transaction do
           self.item_unit_cost = new_item_unit_cost
           self.item_cost = self.item_unit_cost * self.quantity
           self.save
           # Update the booking (cost)
           item_cost_increment = self.item_cost - old_booking_line_item_cost
           total_cost_increment = item_cost_increment
           booking.item_cost += item_cost_increment
           booking.total_cost += total_cost_increment
           booking.total_pending += total_cost_increment
           booking.booking_amount += (total_cost_increment * booking_deposit / 100).round unless booking_deposit == 0
           booking.save
         end
         booking.reload
       end

     end

     #
     # Update item deposit
     #
     def update_item_deposit(new_item_deposit)

       booking_deposit = SystemConfiguration::Variable.get_value('booking.deposit', 0).to_i
       old_booking_line_product_deposit_cost = self.product_deposit_cost
       self.transaction do
         self.product_deposit_unit_cost = (new_item_deposit / booking_line.quantity).round
         self.product_deposit_cost = new_item_deposit
         self.save
         # Update the booking (cost)
         deposit_cost_increment = self.product_deposit_cost - old_booking_line_product_deposit_cost
         total_cost_increment = deposit_cost_increment
         booking.total_cost += total_cost_increment
         booking.total_pending += total_cost_increment
         booking.booking_amount += (total_cost_increment * booking_deposit / 100).round unless booking_deposit == 0
         booking.save
       end
       booking.reload

     end

     # -----------------------------------------------------------------------------------------------------------

  end
end