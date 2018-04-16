require 'data_mapper' unless defined?DataMapper

module Yito
  module Model
    module Booking

      #
      # It represents a booking categories tied to an booking category offer
      #
      class BookingCategoryOfferCategory
        include DataMapper::Resource

        storage_names[:default] = 'bookds_category_offer_categories'

        belongs_to :booking_category_offer, 'BookingCategoryOffer', child_key: [:booking_category_offer_id], parent_key: [:id], key: true
        belongs_to :booking_category, 'BookingCategory', child_key: [:booking_category_code], parent_key: [:code], key: true

      end
    end
  end
end