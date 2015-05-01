require 'data_mapper' unless defined?DataMapper
require 'ysd_md_yito' unless defined?Yito::Model::Finder
require 'ysd_md_calendar' unless defined?Yito::Model::Calendar::Calendar
require 'ysd_md_rates' unless defined?Yito::Model::Rates::PriceDefinition
require 'aspects/ysd-plugins_applicable_model_aspect' unless defined?Plugins::ApplicableModelAspect

module Yito
  module Model
    module Booking

      #
      # It represents a booking category (items are classified in categories)
      #
      class BookingCategory
        include DataMapper::Resource
        extend  Plugins::ApplicableModelAspect           # Extends the entity to allow apply aspects
        extend  Yito::Model::Finder

        storage_names[:default] = 'bookds_categories'

        property :code, String, :field => 'code', :length => 20, :key => true      
        property :type, Enum[:category_of_resources, :activity_or_show, :resource], :default => :category_of_resources
        property :name, String, :field => 'name', :length => 80
        property :short_description, String, :field => 'short_description', :length => 80
        property :description, Text, :field => 'description'
        property :stock, Integer
        property :sort_order, Integer
        belongs_to :calendar, 'Yito::Model::Calendar::Calendar', :required => false
        belongs_to :price_definition, 'Yito::Model::Rates::PriceDefinition', :required => false
        belongs_to :booking_catalog, 'BookingCatalog', :required => false

        def self.types
 
          [{:id => 1, :description => BookingDataSystem.r18n.t.booking_category_type.category},
           {:id => 2, :description => BookingDataSystem.r18n.t.booking_category_type.activity},
           {:id => 3, :description => BookingDataSystem.r18n.t.booking_category_type.resource}]

        end

        def rates_template_code
          booking_catalog ? "booking_tmpl_cat_#{booking_catalog.code}_js" : 'booking_js'
        end 

        def save
          check_calendar! if self.calendar
          check_booking_catalog! if self.booking_catalog
          check_price_definition! if self.price_definition
          super # Invokes the super class to achieve the chain of methods invoked       
        end

        private

        def check_calendar!

          if self.calendar and (not self.calendar.saved?) and loaded = ::Yito::Model::Calendar::Calendar.get(self.calendar.id)
            self.calendar = loaded
          end

        end

        def check_booking_catalog!

          if self.booking_catalog and (not self.booking_catalog.saved?) and loaded = BookingCatalog.get(self.booking_catalog.code)
            self.booking_catalog = loaded
          end

        end

        def check_price_definition!
          if self.price_definition and (not self.price_definition.saved?) and loaded = ::Yito::Model::Rates::PriceDefinition.get(self.price_definition.id)
            self.price_definition = loaded
          end
          if self.price_definition and self.price_definition.id.nil?
            self.price_definition.save
          end
        end

      end

    end
  end
end