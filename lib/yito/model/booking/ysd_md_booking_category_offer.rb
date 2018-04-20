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
        property :reservation_dates_rule, Enum[:from_included, :all_included], default: :from_included
        belongs_to :discount, 'Yito::Model::Rates::Discount', child_key: [:discont_id], parent_key: [:id]
        has n, :offer_booking_categories, 'BookingCategoryOfferCategory',
               :child_key => [:booking_category_offer_id, :booking_category_code], :parent_key => [:id]
        has n, :booking_categories, 'BookingCategory', :through => :offer_booking_categories

        #
        # Search an offer for the booking category in the dates
        #
        def self.search_offer(booking_category_code, date_from, date_to)


          conditions = Conditions::JoinComparison.new('$or',
               [Conditions::JoinComparison.new('$and',
                   [Conditions::Comparison.new('offer_booking_categories.booking_category_code','$eq', booking_category_code),
                              Conditions::Comparison.new('discount.source_date_from','$lte', date_from),
                              Conditions::Comparison.new('discount.source_date_to','$gte', date_to),
                              Conditions::Comparison.new('reservation_dates_rule','$eq', :all_included)
                             ]),
                         Conditions::JoinComparison.new('$and',
                   [Conditions::Comparison.new('offer_booking_categories.booking_category_code','$eq', booking_category_code),
                             Conditions::Comparison.new('discount.source_date_from','$lte', date_from),
                             Conditions::Comparison.new('discount.source_date_to','$gte', date_from),
                             Conditions::Comparison.new('reservation_dates_rule','$eq', :from_included)
                             ])
               ])

          p "conditions:#{booking_category_code}"

          offer = conditions.build_datamapper(BookingCategoryOffer).first

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