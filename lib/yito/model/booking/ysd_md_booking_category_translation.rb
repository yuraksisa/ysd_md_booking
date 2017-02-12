module Yito
  module Model
    module Booking

      module BookingCategoryTranslation

        #
        # Translate the booking category into the language code
        #
        # @param [String] language_code
        #  The language ISO 639-1 code
        #
        # @return [Yito::Model::Booking::BookingCategory]
        #  A new instance of Yito::Model::Booking::BookingCategory with the translated attributes
        #
        def translate(language_code)

          booking_category = nil

          if booking_category_translation = Yito::Model::Booking::Translation::BookingCategoryTranslation.get(code)
            translated_attributes = {}
            booking_category_translation.get_translated_attributes(language_code).each {|term| translated_attributes.store(term.concept.to_sym, term.translated_text)}
            booking_category = ::Yito::Model::Booking::BookingCategory.new(attributes.merge(translated_attributes){ |key, old_value, new_value| new_value.to_s.strip.length > 0?new_value:old_value })
          else
            booking_category = self
          end

          return booking_category

        end

      end
    end
  end
end