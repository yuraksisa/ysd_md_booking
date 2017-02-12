require 'data_mapper' unless defined?DataMapper
require 'ysd_md_translation' unless defined?Model::Translation::Translation

module Yito
  module Model
    module Booking
      module Translation

        #
        # Booking Activity translation
        #
        class BookingActivityTranslation
          include ::DataMapper::Resource

          storage_names[:default] = 'trans_booking_activity_translation'

          belongs_to :booking_activity, '::Yito::Model::Booking::Activity', :child_key => [:booking_activity_id], :parent_key => [:id], :key => true
          belongs_to :translation, 'Model::Translation::Translation', :child_key => [:translation_id], :parent_key => [:id]

          #
          # Creates or updates a booking activity translation
          #
          def self.create_or_update(booking_activity_id, language_code, attributes)

            booking_activity_translation = nil

            BookingActivityTranslation.transaction do
              booking_activity_translation = BookingActivityTranslation.get(booking_activity_id)
              if booking_activity_translation
                booking_activity_translation.set_translated_attributes(language_code, attributes)
              else
                translation = Model::Translation::Translation.create_with_terms(language_code, attributes)
                booking_activity_translation = BookingActivityTranslation.create({
                                                       :booking_activity => ::Yito::Model::Booking::Activity.get(booking_activity_id),
                                                       :translation => translation})
              end
            end

            return booking_activity_translation

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

            Model::Translation::TranslationTerm.find_translations_by_language(translation.id, language_code)

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
