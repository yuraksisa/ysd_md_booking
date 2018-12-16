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

          today = Date.today
          offer = BookingCategoryOffer.by_sql{ |bco| [query_offer(bco), booking_category_code, today, today,
                                              date_from, date_to,
                                              date_from, date_from] }.first

          if offer
            return offer.discount
          else
            return nil
          end

        end
        
        protected
        
        def self.query_offer(bco)
          sql = <<-QUERY
               select #{bco.*}
               FROM #{bco}
                join bookds_category_offer_categories bcoc on bcoc.booking_category_offer_id = #{bco.id} 
                join rateds_discount discount on discount.id = #{bco.discont_id}
                where bcoc.booking_category_code = ? and discount.date_from <= ? and discount.date_to >= ? and
                     ((discount.source_date_from <= ? and discount.source_date_to >= ? and reservation_dates_rule = 2) or 
                      (discount.source_date_from <= ? and discount.source_date_to >= ? and reservation_dates_rule = 1))
          QUERY
        end

      end
    end
  end
end