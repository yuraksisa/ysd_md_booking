require 'data_mapper' unless defined?DataMapper

module Yito
  module Model
    module Booking

      #
      # It represents an offer for a set of booking categories
      #
      class BookingCategoryOffer
        include DataMapper::Resource

        storage_names[:default] = 'bookds_category_offers'

        property :id, Serial
        belongs_to :discount, 'Yito::Model::Rates::Discount', child_key: [:discont_id], parent_key: [:id]
        has n, :offer_booking_categories, 'BookingCategoryOfferCategory', child_key: [:booking_category_offer_id, :booking_category_code], parent_key: [:id]
        has n, :booking_categories, 'BookingCategory', :through => :offer_booking_categories

        #
        # Search an offer for the booking category in the dates
        #
        def self.search_offer(booking_category_code, date_from, date_to)

          offer = BookingCategoryOffer.first(conditions: {'offer_booking_categories.booking_category_code'.to_sym => booking_category_code,
                                                          'discount.source_date_from'.to_sym.lte => date_from,
                                                          'discount.source_date_to'.to_sym.gte => date_to})
          if offer
            return offer.discount
          else
            return nil
          end

        end

      end
    end
  end
end