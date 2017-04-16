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

          transaction do
             # Updates the item
             self.item_id = item_id
             self.item_description = item_description
             # Update the quantity
             self.update_quantity(quantity)
             # Update the cost
             self.update_item_cost(item_unit_cost_base, item_unit_cost, product_deposit_unit_cost)
          end

        end

        #
        # Updates the item quantity
        #
        def update_quantity(quantity)

          if quantity != self.quantity

            old_quantity = self.quantity || 0
            old_item_cost = self.item_cost || 0
            old_item_deposit = self.product_deposit_cost || 0

            transaction do

              # Update the item
              self.quantity = quantity
              self.item_cost = (self.item_unit_cost || 0) * quantity
              self.product_deposit_cost = (self.product_deposit_unit_cost || 0) * quantity
              self.save

              # Update the shopping cart cost
              self.update_shopping_cart_cost(old_item_cost, old_item_deposit)

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

            end
          end
        end

        #
        # update cost
        #
        def update_item_cost(item_unit_cost_base, item_unit_cost, product_deposit_unit_cost)

          transaction do

            old_item_cost = self.item_cost || 0
            old_item_deposit = self.product_deposit_cost || 0

            # Updates the item cost
            self.item_unit_cost_base = item_unit_cost_base
            self.item_unit_cost = item_unit_cost
            self.item_cost = item_unit_cost * quantity
            self.product_deposit_unit_cost = product_deposit_unit_cost
            self.product_deposit_cost = product_deposit_unit_cost * quantity
            self.save

            # Updates the shopping cart cost
            update_shopping_cart_cost(old_item_cost, old_item_deposit)

          end

        end

        protected

        #
        # Update the shoping cart cost (in quantity or product update)
        #
        def update_shopping_cart_cost(old_item_cost, old_item_deposit)
          item_cost_variation = ((self.item_cost || 0) - (old_item_cost || 0))
          item_deposit_variation = ((self.product_deposit_cost || 0) - (old_item_deposit || 0))
          if item_cost_variation != 0 || item_deposit_variation != 0
            # Item cost
            self.shopping_cart.item_cost ||= 0
            self.shopping_cart.item_cost += item_cost_variation
            # Deposit cost
            self.shopping_cart.product_deposit_cost ||= 0
            self.shopping_cart.product_deposit_cost += item_deposit_variation
            # Total cost
            self.shopping_cart.total_cost ||= 0
            self.shopping_cart.total_cost += (item_cost_variation + item_deposit_variation)
            # Booking amount
            self.shopping_cart.booking_amount = self.shopping_cart.total_cost *
              SystemConfiguration::Variable.get_value('booking.deposit', '0').to_i / 100
            begin
              self.shopping_cart.save
            rescue DataMapper::SaveFailureError => error
              p "Error saving shopping cart: #{self.shopping_cart.errors.full_messages.inspect}"
              raise error
            end  
          end
        end

      end
    end
  end
end        