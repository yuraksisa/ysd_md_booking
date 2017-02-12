require 'data_mapper' unless defined?DataMapper

module Yito
  module Model
    module Booking
      class BookingItemHistoric
        include DataMapper::Resource

        storage_names[:default] = 'bookds_item_historics'

        belongs_to :booking_item, 'Yito::Model::Booking::BookingItem',
                   :child_key => [:booking_item_reference], :parent_key => [:reference], :key => true
        property :year, Integer, :key => true

        property :characteristic_1, String, :length => 80
        property :characteristic_2, String, :length => 80
        property :characteristic_3, String, :length => 80
        property :characteristic_4, String, :length => 80

      end
    end
  end
end