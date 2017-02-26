module Yito
  module Model
    module Booking
      #
      # Shopping cart item (renting)
      #
      class ShoppingCartItemRenting
        include DataMapper::Resource    	

        storage_names[:default] = 'bookds_shopping_cart_item_renting'
      
        property :id, Serial
        property :item_id, String, :length => 20, :required => true
        property :item_description, String, :length => 256
        property :optional, String, :length => 40
        property :item_unit_cost_base, Decimal, :precision => 10, :scale => 2
        property :item_unit_cost, Decimal, :precision => 10, :scale => 2
        property :item_cost, Decimal, :precision => 10, :scale => 2
        property :quantity, Integer
        property :product_deposit_unit_cost, Decimal, :precision => 10, :scale => 2, :default => 0
        property :product_deposit_cost, Decimal, :precision => 10, :scale => 2, :default => 0
     
        belongs_to :shopping_cart, 'ShoppingCartRenting', :child_key => [:shopping_cart_renting_id]
        has n, :item_resources, 'ShoppingCartItemResourceRenting', :constraint => :destroy 

        #
        # Set the shopping cart item product
        #
        def set_item(item_id, item_description, quantity, 
                     item_unit_cost_base, item_unit_cost, product_deposit_unit_cost)

          old_quantity = self.quantity || 0
          old_item_cost = self.item_cost || 0
          old_item_deposit = self.product_deposit_cost || 0

          transaction do 

            # Updates the item
            self.item_id = item_id
            self.item_description = item_description
            self.quantity = quantity
            self.item_unit_cost_base = item_unit_cost_base
            self.item_unit_cost = item_unit_cost
            self.item_cost = item_unit_cost * quantity
            self.product_deposit_unit_cost = product_deposit_unit_cost
            self.product_deposit_cost = product_deposit_unit_cost * quantity
            self.save

            # Add or shopping cart item resources
            if quantity < old_quantity
              (quantity..(old_quantity-1)).each do |resource_number|
                self.item_resources[quantity].destroy unless self.item_resources[quantity].nil?
              end
            elsif quantity > old_quantity
              (old_quantity..(quantity-1)).each do |resource_number|
                shopping_cart_item_resource = ShoppingCartItemResourceRenting.new
                shopping_cart_item_resource.item = self
                shopping_cart_item_resource.save
              end
            end

            # Updates the shopping cart
            item_cost_variation = (self.item_cost - old_item_cost)
            item_deposit_variation = (self.product_deposit_cost - old_item_deposit)
            self.shopping_cart.item_cost ||= 0 
            self.shopping_cart.item_cost += item_cost_variation
            self.shopping_cart.product_deposit_cost ||= 0
            self.shopping_cart.product_deposit_cost += item_deposit_variation
            self.shopping_cart.total_cost ||= 0
            self.shopping_cart.total_cost += (item_cost_variation + item_deposit_variation)
            self.shopping_cart.booking_amount = self.shopping_cart.total_cost * 
              SystemConfiguration::Variable.get_value('booking.deposit', '0').to_i / 100
            self.shopping_cart.save

          end

        end

      end
    end
  end
end        