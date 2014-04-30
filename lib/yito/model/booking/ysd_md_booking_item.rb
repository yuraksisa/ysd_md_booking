require 'data_mapper' unless defined?DataMapper
require 'ysd_md_yito' unless defined?Yito::Model::Finder
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

        #
        # Override the save method to check the category
        #
        def save

          if category
            check_category!
          end

          super

        end

        private

        def check_category!

          if category and (not category.saved?) and loaded_category = Category.get(category.code)
            category = loaded_category
          end

        end

      end

    end
  end
end