module Yito
  module Model
    module Booking

      module BookingExtraTranslation

        #
        # Translate the booking extra into the language code
        #
        # @param [String] language_code
        #  The language ISO 639-1 code
        #
        # @return [Yito::Model::Booking::BookingExtra]
        #  A new instance of Yito::Model::Booking::BookingExtra with the translated attributes
        #
        def translate(language_code)

          booking_extra = nil

          if booking_extra_translation = Yito::Model::Booking::Translation::BookingExtraTranslation.get(code)
            translated_attributes = {}
            booking_extra_translation.get_translated_attributes(language_code).each {|term| translated_attributes.store(term.concept.to_sym, term.translated_text)}
            booking_extra = ::Yito::Model::Booking::BookingExtra.new(attributes.merge(translated_attributes){ |key, old_value, new_value| new_value.to_s.strip.length > 0?new_value:old_value })
          else
            booking_extra = self
          end

          return booking_extra

        end

      end
    end
  end
end