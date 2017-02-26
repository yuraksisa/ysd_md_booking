module Yito
  module Model
    module Booking
      #
      # Shopping cart item resource (renting)
      #
      class ShoppingCartItemResourceRenting
        include DataMapper::Resource
        include BookingDataSystem::BookingHeightWeight

        storage_names[:default] = 'bookds_shopping_cart_item_resource_renting'
      
        property :id, Serial

        property :resource_user_name, String, :length => 80
        property :resource_user_surname, String, :length => 80
        property :resource_user_document_id, String, :length => 50
        property :resource_user_phone, String, :length => 15
        property :resource_user_email, String, :length => 40

        property :resource_user_2_name, String, :length => 80
        property :resource_user_2_surname, String, :length => 80
        property :resource_user_2_document_id, String, :length => 50
        property :resource_user_2_phone, String, :length => 15
        property :resource_user_2_email, String, :length => 40

        property :pax, Integer, :default => 1 # Number of people responsible of the resource

        belongs_to :item, 'ShoppingCartItemRenting', :child_key => [:shopping_cart_item_renting_id]

        property :booking_item_category, String, :length => 20
        property :booking_item_reference, String, :length => 50
        property :booking_item_stock_model, String, :length => 80
        property :booking_item_stock_plate, String, :length => 80
        property :booking_item_characteristic_1, String, :length => 80
        property :booking_item_characteristic_2, String, :length => 80
        property :booking_item_characteristic_3, String, :length => 80
        property :booking_item_characteristic_4, String, :length => 80

      end
    end
  end
end        