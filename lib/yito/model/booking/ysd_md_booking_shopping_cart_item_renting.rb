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
        property :item_description_customer_translation, String, :length => 256
        property :optional, String, :length => 40

        property :quantity, Integer

        property :item_unit_cost_base, Decimal, :precision => 10, :scale => 2
        property :item_unit_cost, Decimal, :precision => 10, :scale => 2
        property :item_cost, Decimal, :precision => 10, :scale => 2

        property :product_deposit_unit_cost, Decimal, :precision => 10, :scale => 2, :default => 0
        property :product_deposit_cost, Decimal, :precision => 10, :scale => 2, :default => 0

        property :category_supplement_1_unit_cost, Decimal, scale: 2, precision: 10, default: 0     
        property :category_supplement_1_cost, Decimal, scale: 2, precision: 10, default: 0     
        property :category_supplement_2_unit_cost, Decimal, scale: 2, precision: 10, default: 0     
        property :category_supplement_2_cost, Decimal, scale: 2, precision: 10, default: 0     
        property :category_supplement_3_unit_cost, Decimal, scale: 2, precision: 10, default: 0     
        property :category_supplement_3_cost, Decimal, scale: 2, precision: 10, default: 0     

        belongs_to :shopping_cart, 'ShoppingCartRenting', :child_key => [:shopping_cart_renting_id]
        has n, :item_resources, 'ShoppingCartItemResourceRenting', :constraint => :destroy 

        # Item supplier
        belongs_to :supplier, 'Yito::Model::Suppliers::Supplier', child_key: [:supplier_id], parent_id: [:id], required: false

        #
        # Set the shopping cart item product
        #
        # == Parameters::
        #
        # item_id:: The item id
        # item_description:: The item description
        # quantity:: The quantity
        # item_unit_cost_base:: Unit cost base
        # item_unit_cost:: Unit cost
        # product_deposit_unit_cost:: Deposit unit cost
        # category_supplement_1_unit_cost:: Category supplement 1
        # category_supplement_2_unit_cost:: Category supplement 2
        # category_supplement_3_unit_cost:: Category supplement 3
        #        
        def set_item(item_id, item_description, quantity, 
                     item_unit_cost_base, item_unit_cost, 
                     product_deposit_unit_cost,
                     category_supplement_1_unit_cost,
                     category_supplement_2_unit_cost,
                     category_supplement_3_unit_cost)

          transaction do
             # Updates the item
             self.item_id = item_id
             self.item_description = item_description
             if product = ::Yito::Model::Booking::BookingCategory.get(item_id)
               product_customer_translation = product.translate(shopping_cart.customer_language)
               self.item_description_customer_translation = (product_customer_translation.nil? ? item_description : product_customer_translation.name)
             else
               self.item_description_customer_translation = item_description
             end
             # Update the quantity
             self.update_quantity(quantity)
             # Update the cost
             self.update_item_cost(item_unit_cost_base, 
                                   item_unit_cost, 
                                   product_deposit_unit_cost,
                                   category_supplement_1_unit_cost,
                                   category_supplement_2_unit_cost,
                                   category_supplement_3_unit_cost)
          end

        end

        #
        # Remove the item from the shopping cart
        #
        def remove_item

          transaction do
            self.destroy
            
            self.shopping_cart.item_cost ||= 0
            self.shopping_cart.item_cost -= self.item_cost

            self.shopping_cart.product_deposit_cost ||= 0
            self.shopping_cart.product_deposit_cost -= self.product_deposit_cost
            
            self.shopping_cart.category_supplement_1_cost ||= 0
            self.shopping_cart.category_supplement_1_cost -= self.category_supplement_1_cost
            self.shopping_cart.category_supplement_2_cost ||= 0
            self.shopping_cart.category_supplement_2_cost -= self.category_supplement_2_cost
            self.shopping_cart.category_supplement_3_cost ||= 0
            self.shopping_cart.category_supplement_3_cost -= self.category_supplement_3_cost

            self.shopping_cart.calculate_cost(false, true)
            begin
              self.shopping_cart.save
            rescue DataMapper::SaveFailureError => error
              p "Error saving shopping cart: #{self.shopping_cart.errors.full_messages.inspect}"
              raise error
            end
          end

        end

        #
        # Updates the item quantity
        #
        # == Parameters::
        #
        # quantity:: New quantity
        #
        def update_quantity(quantity)

          if quantity != self.quantity

            old_quantity = self.quantity || 0
            old_item_cost = self.item_cost || 0
            old_item_deposit = self.product_deposit_cost || 0
            old_category_supplement_1_cost = self.category_supplement_1_cost || 0
            old_category_supplement_2_cost = self.category_supplement_2_cost || 0
            old_category_supplement_3_cost = self.category_supplement_3_cost || 0

            transaction do

              # Update the item
              self.quantity = quantity
              self.item_cost = (self.item_unit_cost || 0) * quantity
              self.product_deposit_cost = (self.product_deposit_unit_cost || 0) * quantity
              self.category_supplement_1_cost = (self.category_supplement_1_unit_cost || 0) * quantity
              self.category_supplement_2_cost = (self.category_supplement_2_unit_cost || 0) * quantity
              self.category_supplement_3_cost = (self.category_supplement_3_unit_cost || 0) * quantity
              self.save

              # Update the shopping cart cost
              self.shopping_cart_item_cost_variation(old_item_cost, 
                                                     old_item_deposit,                                                     
                                                     old_category_supplement_1_cost,
                                                     old_category_supplement_2_cost,
                                                     old_category_supplement_3_cost)
              self.shopping_cart.calculate_cost(false, true)

              begin
                self.shopping_cart.save
              rescue DataMapper::SaveFailureError => error
                p "Error saving shopping cart: #{self.shopping_cart.errors.full_messages.inspect}"
                raise error
              end

              # Add or shopping cart item resources
              if quantity < old_quantity
                (quantity..(old_quantity-1)).each do |resource_number|
                  self.item_resources[quantity].destroy unless self.item_resources[quantity].nil?
                  self.item_resources.reload
                end
              elsif quantity > old_quantity
                product = ::Yito::Model::Booking::BookingCategory.get(item_id)
                (old_quantity..(quantity-1)).each do |resource_number|
                  shopping_cart_item_resource = ShoppingCartItemResourceRenting.new
                  shopping_cart_item_resource.item = self
                  shopping_cart_item_resource.pax = product.capacity unless product.nil?
                  shopping_cart_item_resource.save
                end
              end

            end
          end
        end

        #
        # update item cost
        #
        # == Parameters::
        #
        # item_unit_cost_base:: Unit cost base
        # item_unit_cost:: Unit cost
        # product_deposit_unit_cost:: Deposit unit cost       
        # category_supplement_1_unit_cost:: Category supplement 1
        # category_supplement_2_unit_cost:: Category supplement 2
        # category_supplement_3_unit_cost:: Category supplement 3        
        #
        def update_item_cost(item_unit_cost_base, 
                             item_unit_cost, 
                             product_deposit_unit_cost,
                             category_supplement_1_unit_cost,
                             category_supplement_2_unit_cost,
                             category_supplement_3_unit_cost)

          transaction do

            old_item_cost = self.item_cost || 0
            old_item_deposit = self.product_deposit_cost || 0
            old_category_supplement_1_cost = self.category_supplement_1_cost || 0
            old_category_supplement_2_cost = self.category_supplement_2_cost || 0
            old_category_supplement_3_cost = self.category_supplement_3_cost || 0

            # Updates the item cost
            self.item_unit_cost_base = item_unit_cost_base
            self.item_unit_cost = item_unit_cost
            self.item_cost = item_unit_cost * self.quantity
            self.product_deposit_unit_cost = product_deposit_unit_cost
            self.product_deposit_cost = product_deposit_unit_cost * quantity
            self.category_supplement_1_unit_cost = category_supplement_1_unit_cost
            self.category_supplement_1_cost = category_supplement_1_unit_cost * quantity
            self.category_supplement_2_unit_cost = category_supplement_2_unit_cost
            self.category_supplement_2_cost = category_supplement_2_unit_cost * quantity
            self.category_supplement_3_unit_cost = category_supplement_3_unit_cost
            self.category_supplement_3_cost = category_supplement_3_unit_cost * quantity

            self.save

            # Updates the shopping cart cost
            self.shopping_cart_item_cost_variation(old_item_cost, 
                                                   old_item_deposit,
                                                   old_category_supplement_1_cost,
                                                   old_category_supplement_2_cost,
                                                   old_category_supplement_3_cost)
            self.shopping_cart.calculate_cost(false, true)
            begin
              self.shopping_cart.save
            rescue DataMapper::SaveFailureError => error
              p "Error saving shopping cart: #{self.shopping_cart.errors.full_messages.inspect}"
              raise error
            end

          end

        end

        protected

        #
        # Update shopping cart cost variation
        #
        # Parameters::
        # 
        # old_item_cost:: Old item cost
        # old_item_deposit:: Old item deposit
        # old_category_supplement_1_cost:: Old category supplement 1
        # old_category_supplement_2_cost:: Old category supplement 2
        # old_category_supplement_3_cost:: Old category supplement 3
        #
        def shopping_cart_item_cost_variation(old_item_cost, old_item_deposit,
                                              old_category_supplement_1_cost, 
                                              old_category_supplement_2_cost,
                                              old_category_supplement_3_cost)
          
          item_cost_variation = ((self.item_cost || 0) - (old_item_cost || 0)).round
          item_deposit_variation = ((self.product_deposit_cost || 0) - (old_item_deposit || 0)).round          
          
          category_supplement_1_variation = ((self.category_supplement_1_cost || 0) - (old_category_supplement_1_cost || 0)).round
          category_supplement_2_variation = ((self.category_supplement_2_cost || 0) - (old_category_supplement_2_cost || 0)).round
          category_supplement_3_variation = ((self.category_supplement_3_cost || 0) - (old_category_supplement_3_cost || 0)).round

          self.shopping_cart.item_cost ||= 0
          self.shopping_cart.item_cost += item_cost_variation

          self.shopping_cart.product_deposit_cost ||= 0
          self.shopping_cart.product_deposit_cost += item_deposit_variation

          self.shopping_cart.category_supplement_1_cost ||= 0
          self.shopping_cart.category_supplement_1_cost += category_supplement_1_variation
          self.shopping_cart.category_supplement_2_cost ||= 0
          self.shopping_cart.category_supplement_2_cost += category_supplement_2_variation
          self.shopping_cart.category_supplement_3_cost ||= 0
          self.shopping_cart.category_supplement_3_cost += category_supplement_3_variation

        end

      end
    end
  end
end        