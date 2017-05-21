module Yito
  module Model
    module Booking

      module BookingActivityTranslation

        attr_accessor :language_code
        
        #
        # Translate the booking category into the language code
        #
        # @param [String] language_code
        #  The language ISO 639-1 code
        #
        # @return [Yito::Model::Booking::BookingActivity]
        #  A new instance of Yito::Model::Booking::BookingActivity with the translated attributes
        #
        def translate(language_code)

          booking_activity = nil

          if booking_activity_translation = Yito::Model::Booking::Translation::BookingActivityTranslation.get(id)
            translated_attributes = {}
            booking_activity_translation.get_translated_attributes(language_code).each {|term| translated_attributes.store(term.concept.to_sym, term.translated_text)}
            booking_activity = ::Yito::Model::Booking::Activity.new(attributes.merge(translated_attributes){ |key, old_value, new_value| new_value.to_s.strip.length > 0?new_value:old_value })
          else
            booking_activity = self
          end

          booking_activity.language_code = language_code          
          
          return booking_activity

        end

      end
    end
  end
end