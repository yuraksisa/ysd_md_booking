require 'data_mapper' unless defined?DataMapper

module Yito
  module Model
    module Booking
      #
      # It represents a pickup/return place
      #
      class PickupReturnPlace
        include DataMapper::Resource
        include Yito::Model::Booking::PickupReturnPlaceTranslation
        
        storage_names[:default] = 'bookds_pickup_places'

        property :id, Serial
        property :name, String, :length => 80
        property :is_pickup, Boolean
        property :is_return, Boolean
        property :price, Decimal, :scale => 2, :precision => 10
        belongs_to :pickup_return_place_definition, :child_key => [:place_definition_id], :parent_key => [:id]
        belongs_to :rental_location, required: false

        def save
          check_pickup_return_place_definition! if self.pickup_return_place_definition
          super
        end

        private

        def check_pickup_return_place_definition!
      
          if self.pickup_return_place_definition and (not self.pickup_return_place_definition.saved?) and loaded = PickupReturnPlaceDefinition.get(self.pickup_return_place_definition.id)
            self.pickup_return_place_definition = loaded
          end

        end         

      end
    end
  end
end