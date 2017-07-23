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
        include Yito::Model::Booking::BookingCategoryTranslation
        
        storage_names[:default] = 'bookds_categories'

        property :code, String, :field => 'code', :length => 20, :key => true      
        property :type, Enum[:category_of_resources, :resource], :default => :category_of_resources
        property :name, String, :field => 'name', :length => 80
        property :short_description, String, :field => 'short_description', :length => 80
        property :description, Text, :field => 'description'
        property :stock_control, Boolean, :default => false
        property :stock, Integer, :default => 0
        property :sort_order, Integer, :default => 0
        property :deposit, Decimal, :scale => 2, :precision => 10, :default => 0
        property :capacity, Integer, :default => 0
        property :active, Boolean, :default => true
        property :web_public, Boolean, :default => true
        property :alias, String, :length => 80       
 
        belongs_to :calendar, 'Yito::Model::Calendar::Calendar', :required => false
        belongs_to :price_definition, 'Yito::Model::Rates::PriceDefinition', :required => false
        belongs_to :booking_catalog, 'BookingCatalog', :required => false

        before :create do
          if self.alias.nil? or self.alias.empty?     
            self.alias = File.join('/', Time.now.strftime('%Y%m%d') , UnicodeUtils.nfkd(self.name).gsub(/[^\x00-\x7F]/,'').gsub(/\s/,'-'))
          end
        end

        #
        # Count the defined stock
        #
        def defined_stock
          BookingItem.all(category_code: code, active: true, assignable: true).count
        end

        #
        # Check if the product is ready to start selling it
        #
        def ready?
          !code.nil? and !code.empty? and 
          !name.nil? and !name.empty? and 
          !short_description.nil? and !short_description.empty? and
          !description.nil? and !description.empty? and
          !price_definition.nil? 
        end
        
        #
        # Ready warnings
        #
        def ready_warnings
          warnings = []
          warnings << BookingDataSystem.r18n.t.code_empty if code.nil? or code.empty?
          warnings << BookingDataSystem.r18n.t.name_empty if name.nil? or name.empty?
          warnings << BookingDataSystem.r18n.t.short_description_empty if short_description.nil? or short_description.empty?
          warnings << BookingDataSystem.r18n.t.description_empty if description.nil? or description.empty?
          warnings << BookingDataSystem.r18n.t.price_definition_empty if price_definition.nil?
          return warnings
        end
        
        alias_method :ready, :ready?

        def self.types
          [{:id => 1, :description => BookingDataSystem.r18n.t.booking_category_type.category},
           {:id => 2, :description => BookingDataSystem.r18n.t.booking_category_type.resource}]
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
        
        #
        # Exporting to json
        #
        def as_json(options={})

          if options.has_key?(:only)
            super(options)
          else
            relationships = options[:relationships] || {}
            methods = options[:methods] || []
            methods << :ready
            methods << :ready_warnings
            methods << :defined_stock
            super(options.merge({:relationships => relationships, :methods => methods}))
          end

        end
        
        #
        # Calculate the unit cost for a date and a number of days
        #
        def unit_price(date_from, ndays, mode=nil)
          if price_definition
            if mode.nil?
              mode = SystemConfiguration::Variable.get_value('booking.renting_calendar_season_mode','first_day')
              mode = (mode == 'first_day' ? :first_season_day : :season_days_average)
            end
            price_definition.calculate_price(date_from.to_date, ndays, mode)
          else
            return 0
          end
        end

        private

        def check_calendar!

          if self.calendar and (not self.calendar.saved?) and loaded = ::Yito::Model::Calendar::Calendar.get(self.calendar.id)
            self.calendar = loaded
          end

          if self.calendar and self.calendar.id.nil?
            self.calendar.save
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