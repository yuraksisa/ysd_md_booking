require 'data_mapper' unless defined?DataMapper

module Yito
  module Model
    module Booking
      #
      # It represents a pickup/return place
      #
      class PickupReturnPlaceDefinition
        include DataMapper::Resource

        storage_names[:default] = 'bookds_pickup_place_defs'

        property :id, Serial
        property :name, String, :length => 80
        has n, :pickup_return_places, :child_key => [:place_definition_id], :parent_key => [:id], :constraint => :destroy

      end
    end
  end
end