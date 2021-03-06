module Yito
  module Model
    module Booking
      #
      # Shopping cart (extra) renting
      #
      class ShoppingCartExtraRenting
        include DataMapper::Resource    	

        storage_names[:default] = 'bookds_shopping_cart_extra_renting'
      
        property :id, Serial

        property :extra_id, String, :required => true, :length => 20
        property :extra_description, String, :required => false, :length => 256
        property :extra_description_customer_translation, String, length: 256
        property :extra_unit_cost, Decimal, :scale => 2, :precision => 10
        property :extra_cost, Decimal, :scale => 2, :precision => 10
        property :quantity, Integer
     
        belongs_to :shopping_cart, 'ShoppingCartRenting', :child_key => [:shopping_cart_renting_id]

        #
        # After destroying an extra, updates the shopping cart information
        #
        after :destroy do
           shopping_cart.extras_cost -= extra_cost
           shopping_cart.total_cost -= extra_cost
           shopping_cart.save
        end

        #
        # Set the item
        #
        def set_item(extra_id, extra_description, extra_unit_cost, quantity)
          transaction do
            self.extra_id = extra_id
            self.extra_description = extra_description
            if extra = ::Yito::Model::Booking::BookingExtra.get(extra_id)
              extra_customer_translation = extra.translate(shopping_cart.customer_language)
              self.extra_description_customer_translation = (extra_customer_translation.nil? ? extra_description : extra_customer_translation.name)
            else
              self.extra_description_customer_translation = extra_description
            end
            self.quantity = quantity
            self.update_extra_cost(extra_unit_cost)
            self.extra_unit_cost = extra_unit_cost
          end
        end

        #
        # Update the extra quantity
        #
        def update_quantity(quantity)
          if quantity != self.quantity
            old_cost = self.extra_cost || 0
            transaction do
               self.quantity = quantity
               self.extra_cost = self.extra_unit_cost * quantity
               self.save
               shopping_cart.extras_cost += (self.extra_cost - old_cost)
               shopping_cart.calculate_cost(false, false)
               shopping_cart.save
            end
          end
        end

        #
        # Update extra cost
        #
        def update_extra_cost(extra_unit_cost)
          if extra_unit_cost != self.extra_unit_cost
            old_cost = self.extra_cost || 0
            transaction do
              self.extra_unit_cost = extra_unit_cost
              self.extra_cost = extra_unit_cost * quantity
              self.save
              shopping_cart.extras_cost = (shopping_cart.extras_cost || 0) + (self.extra_cost - old_cost)
              shopping_cart.calculate_cost(false, false)
              shopping_cart.save
            end
          end
        end

      end
    end
  end
end        