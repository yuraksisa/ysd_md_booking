module Yito
  module Model
    module Booking

      module PickupReturnPlaceTranslation

        attr_accessor :language_code
        
        #
        # Translate the booking pickup/return place into the language code
        #
        # @param [String] language_code
        #  The language ISO 639-1 code
        #
        # @return [Yito::Model::Booking::PickupReturnPlace]
        #  A new instance of Yito::Model::Booking::PickupReturnPlace with the translated attributes
        #
        def translate(language_code)

          pickup_return_place = nil

          if pickup_return_place_translation = Yito::Model::Booking::Translation::BookingPickupReturnPlaceTranslation.get(id)
            translated_attributes = {}
            pickup_return_place_translation.get_translated_attributes(language_code).each {|term| translated_attributes.store(term.concept.to_sym, term.translated_text)}
            pickup_return_place = ::Yito::Model::Booking::PickupReturnPlace.new(attributes.merge(translated_attributes){ |key, old_value, new_value| new_value.to_s.strip.length > 0?new_value:old_value })
          else
            pickup_return_place = self
          end

          pickup_return_place.language_code = language_code          
          
          return pickup_return_place

        end

      end
    end
  end
end