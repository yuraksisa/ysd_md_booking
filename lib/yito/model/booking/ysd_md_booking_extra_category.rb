require 'data_mapper' unless defined?DataMapper

module Yito
  module Model
    module Booking

      #
      # It represents a booking categories tied to an booking category offer
      #
      class BookingExtraCategory
        include DataMapper::Resource

        storage_names[:default] = 'bookds_extra_categories'

        belongs_to :booking_extra, 'BookingExtra', child_key: [:booking_extra_code], parent_key: [:code], key: true
        belongs_to :booking_category, 'BookingCategory', child_key: [:booking_category_code], parent_key: [:code], key: true

      end
    end
  end
end