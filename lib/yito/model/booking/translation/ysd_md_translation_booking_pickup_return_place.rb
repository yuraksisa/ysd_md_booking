require 'data_mapper' unless defined?DataMapper
require 'ysd_md_translation' unless defined?Model::Translation::Translation

module Yito
  module Model
    module Booking
      module Translation

        #
        # Pickup/return place translation
        #
        class BookingPickupReturnPlaceTranslation
          include ::DataMapper::Resource

          storage_names[:default] = 'trans_booking_pickup_return_place_translation'

          belongs_to :pickup_return_place, '::Yito::Model::Booking::PickupReturnPlace', :child_key => [:pickup_return_place_id], :parent_key => [:id], :key => true
          belongs_to :translation, 'Model::Translation::Translation', :child_key => [:translation_id], :parent_key => [:id]

          #
          # Creates or updates a pickup/return place translation
          #
          def self.create_or_update(pickup_return_place_id, language_code, attributes)

            pickup_return_place_translation = nil

            BookingPickupReturnPlaceTranslation.transaction do
              pickup_return_place_translation = BookingPickupReturnPlaceTranslation.get(pickup_return_place_id)
              if pickup_return_place_translation
                pickup_return_place_translation.set_translated_attributes(language_code, attributes)
              else
                translation = ::Model::Translation::Translation.create_with_terms(language_code, attributes)
                pickup_return_place_translation = BookingPickupReturnPlaceTranslation.create({
                                 :pickup_return_place => ::Yito::Model::Booking::PickupReturnPlace.get(pickup_return_place_id),
                                 :translation => translation})
              end
            end

            return pickup_return_place_translation

          end

          #
          # Get the term translated attributes
          #
          # @param [String] language_code
          #  The language code
          #
          # @return [Array]
          #  An array of TranslationTerm which contains all the translations terms in the request language
          #
          def get_translated_attributes(language_code)

            ::Model::Translation::TranslationTerm.find_translations_by_language(translation.id, language_code)

          end

          #
          # Updates the translated attributes
          #
          # @param [Numeric] term_id
          #  The term id
          #
          # @param [String] language_code
          #  The language code
          #
          # @param [Hash] attributes
          #  The attributes
          #
          def set_translated_attributes(language_code, attributes)

            translation.update_terms(language_code, attributes)

          end

        end
      end
    end
  end
end
