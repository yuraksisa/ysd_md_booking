require 'data_mapper' unless defined?DataMapper
require 'ysd_md_yito' unless defined?Yito::Model::Finder
require 'ysd_md_calendar' unless defined?Yito::Model::Calendar::Calendar
require 'ysd_md_rates' unless defined?Yito::Model::Rates::PriceDefinition
require 'aspects/ysd-plugins_applicable_model_aspect' unless defined?Plugins::ApplicableModelAspect

module Yito
  module Model
    module Booking
  	
      #
      # It represents a booking item (something that can be booked)
      #
      class BookingItem
        include DataMapper::Resource
        extend  Plugins::ApplicableModelAspect           # Extends the entity to allow apply aspects
        extend  Yito::Model::Finder

        storage_names[:default] = 'bookds_items'

        property :reference, String, :field => 'reference', :length => 50, :key => true
        property :name, String, :field => 'name', :length => 80
        property :description, Text, :field => 'description'
        belongs_to :category, 'Yito::Model::Booking::BookingCategory', 
          :child_key => [:category_code], :parent_key => [:code]
        belongs_to :calendar, 'Yito::Model::Calendar::Calendar', :required => false
        belongs_to :price_definition, 'Yito::Model::Rates::PriceDefinition', :required => false

        #
        # Override the save method to check the category
        #
        def save
          
          check_category! if self.category
          check_calendar! if self.calendar
          check_price_definition! if self.price_definition

          super

        end

        private

        def check_category!
          if self.category and (not self.category.saved?) and loaded = BookingCategory.get(self.category.code)
            self.category = loaded
          end
        end

        def check_calendar!
          if self.calendar and (not self.calendar.saved?) and loaded = ::Yito::Model::Calendar::Calendar.get(self.calendar.id)
            self.calendar = loaded
          end
        end

        def check_price_definition!
          if self.price_definition and (not self.price_definition.saved?) and loaded = ::Yito::Model::Rates::PriceDefinition.get(self.price_definition.id)
            self.price_definition = loaded
          end
        end

      end

    end
  end
end