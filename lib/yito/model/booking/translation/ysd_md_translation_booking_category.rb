require 'data_mapper' unless defined?DataMapper
require 'ysd_md_translation' unless defined?Model::Translation::Translation

module Yito
  module Model
    module Booking
      module Translation

        #
        # Booking Category translation
        #
        class BookingCategoryTranslation
          include ::DataMapper::Resource

          storage_names[:default] = 'trans_booking_category_translation'

          belongs_to :booking_category, '::Yito::Model::Booking::BookingCategory', :child_key => [:booking_category_code], :parent_key => [:code], :key => true
          belongs_to :translation, 'Model::Translation::Translation', :child_key => [:translation_id], :parent_key => [:id]

          #
          # Creates or updates a booking category translation
          #
          def self.create_or_update(booking_category_code, language_code, attributes)

            booking_category_translation = nil

            BookingCategoryTranslation.transaction do
              booking_category_translation = BookingCategoryTranslation.get(booking_category_code)
              if booking_category_translation
                booking_category_translation.set_translated_attributes(language_code, attributes)
              else
                translation = ::Model::Translation::Translation.create_with_terms(language_code, attributes)
                booking_category_translation = BookingCategoryTranslation.create({
                                                  :booking_category => ::Yito::Model::Booking::BookingCategory.get(booking_category_code),
                                                  :translation => translation})
              end
            end

            return booking_category_translation

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
