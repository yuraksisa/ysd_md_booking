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

        property :code, String, :length => 20, :key => true
        property :type, Enum[:category_of_resources, :resource], :default => :category_of_resources
        property :name, String, :length => 80
        property :short_description, String, :length => 80
        property :title, String, length: 100
        property :subtitle, Text
        property :description, Text
        property :stock_control, Boolean, :default => false
        property :stock, Integer, :default => 0
        property :sort_order, Integer, :default => 0
        property :deposit, Decimal, :scale => 2, :precision => 10, :default => 0
        property :capacity, Integer, :default => 0
        property :capacity_children, Integer, :default => 0
        property :active, Boolean, :default => true
        property :web_public, Boolean, :default => true
        property :alias, String, :length => 80
        property :color, String, length: 50

        property :from_price, Decimal, :scale => 2, :precision => 10, :default => 0
        property :from_price_offer, Decimal, :scale => 2, :precision => 10, :default => 0
        
        belongs_to :calendar, 'Yito::Model::Calendar::Calendar', :required => false
        belongs_to :price_definition, 'Yito::Model::Rates::PriceDefinition', :required => false
        belongs_to :booking_catalog, 'BookingCatalog', :required => false
        
        include Yito::Model::Booking::SalesManagement

        has n, :category_classifier_terms, 'CategoryClassifierTerm', :child_key => [:category_code], :parent_key => [:code], :constraint => :destroy
        has n, :classifier_terms, '::Yito::Model::Classifier::ClassifierTerm', :through => :category_classifier_terms, :via => :classifier_term

        has n, :booking_categories_sales_channels, 'BookingCategoriesSalesChannel', :child_key => [:booking_category_code], :parent_key => [:code], :constraint => :destroy
        #has n, :sales_channels, 'Yito::Model::SalesChannel::SalesChannel', :through => :booking_categories_sales_channels, :via => :sales_channel

        # -------------------------------- Hooks ----------------------------------------------

        #
        # Before create
        #
        #   - build the alias
        #   - initialitzation depending on type
        #      a. category_of_resources : none
        #      b. resource: 1 item in stock (and stock control)
        #   - setup a calendar
        #   - setup the price definition
        #
        before :create do
          # Get the alias
          if self.alias.nil? or self.alias.empty?     
            self.alias = File.join('/', UnicodeUtils.nfkd(self.name).gsub(/[^\x00-\x7F]/,'').gsub(/\s/,'-'))[0..79]
          end
          # Setup depending on the type
          if type == :resource
            self.stock_control = true
            self.stock = 1
          end
          # Create the calendar associated to the category
          if calendar.nil?
            calendar = Yito::Model::Calendar::Calendar.new(name: self.code, description: self.name)
            calendar.event_type_calendars << Yito::Model::Calendar::EventTypeCalendar.new(
                event_type: Yito::Model::Calendar::EventType.first_or_create({name: 'not_available'}, {name: 'not_available', description: 'No disponible'}))
            calendar.event_type_calendars << Yito::Model::Calendar::EventTypeCalendar.new(
                event_type: Yito::Model::Calendar::EventType.first_or_create({name: 'payment_enabled'}, {name: 'payment_enabled', description: 'Permitir pago'}))
            calendar.save
            self.calendar = calendar
          end
          # Create the rates associated to the category
          if price_definition.nil?
            if booking_item_family = ::Yito::Model::Booking::ProductFamily.get(SystemConfiguration::Variable.get_value('booking.item_family'))
              price_definition = booking_item_family.build_product_price_definition(self.code, self.name)
              price_definition.save
              self.price_definition = price_definition
            end
          end
        end

        #
        # After create
        # 
        #  - post-initialitzation depending on type
        #      a. category_of_resources : none
        #      b. resource: create an stock item
        # 
        after :create do
          # If the type is a resource, create and item that represents the resource
          if type == :resource
            BookingItem.create(reference: self.code, name: self.name, category: self)
          end
        end

        after :destroy do

          # Delete the calendar
          self.calendar.destroy if calendar

          # Delete the rates
          self.price_definition.destroy if price_definition

        end

        # ----------------------------   Class methods  -------------------------------------

        #
        # Get the category types
        #
        # category_of_resources : It represents a category (for example rent a car categories ...)
        # resource : It represents a resource (for example accomodation, boat charter, ...)
        #
        def self.types
          [{:id => 'category_of_resources', :description => BookingDataSystem.r18n.t.booking_category_type.category},
           {:id => 'resource', :description => BookingDataSystem.r18n.t.booking_category_type.resource}]
        end

        #
        # Search for products (availability and categories)
        #
        # == Parameters:
        # date_from::
        #   The reservation starting date
        # time_from::
        #   The reservation starting time
        # date_to::
        #   The reservation ending date
        # time_to::
        #   The reservation ending time
        # days::
        #   The reservation number of days
        # options::
        #   A hash with some options
        #   :locale -> The locale for the translations
        #   :full_information -> Shows the stock information (total and available)
        #   :product_code -> The product code (for a specific category search)
        #   :web_public -> Include only web_public categories
        #   :sales_channel_code -> The sales channel code (nil for default)
        #   :promotion_code -> The promotion code
        #   :apply_promotion_code -> Apply the promotion code
        #   :include_stock -> Include the stock references in the result (if we want to known the free resources)
        #   :ignore_urge -> It's a hash with two keys, origin and id. It allows to avoid the pre-assignation of the
        #              pending reservation. It's used when trying to assign resources to this reservation
        # == Returns:
        # An array of RentingSearch items
        #
        def self.search(date_from, time_from, date_to, time_to, days, options={})
          
          RentingSearch.search(date_from, time_from, date_to, time_to, days, options)

        end

        #
        # Calcualte discount
        #
        def self.discount(product_price, item_id, from, to, rates_promotion_code=nil)

          discount = 0

          # Apply promotion code
          if rates_promotion_code
            case rates_promotion_code.discount_type
              when :percentage
                discount = product_price * (rates_promotion_code.value / 100)
              when :amount
                discount = rates_promotion_code.value
            end
          else
            category_discount = ::Yito::Model::Booking::BookingCategoryOffer.search_offer(item_id, from, to)
            # Apply offers
            if category_discount
              case category_discount.discount_type
                when :percentage
                  discount = product_price * (category_discount.value / 100)
                when :amount
                  discount = category_discount.value
              end
            end
          end

          return discount

        end

        # ---------------------------- Instance methods -------------------------------------

        def save
          check_calendar! if self.calendar
          check_booking_catalog! if self.booking_catalog
          check_price_definition! if self.price_definition
          super # Invokes the super class to achieve the chain of methods invoked
        end
        
        #
        # Search for products (availability and categories)
        #
        # == Parameters:
        # date_from::
        #   The reservation starting date
        # time_fom::
        #   The reservation starting time
        # date_to::
        #   The reservation ending date
        # time_to::
        #   The reservation ending time
        # days::
        #   The reservation number of days
        # options::
        #   A hash with some options
        #   :locale -> The locale for the translations
        #   :full_information -> Shows the stock information (total and available)
        #   :web_public -> Include only web_public categories
        #   :sales_channel_code -> The sales channel code  
        #
        # == Returns:
        # An array of RentingSearch items
        #        
        def search(date_from, time_from, date_to, time_to, days, options={})
          RentingSearch.search(date_from, time_from, date_to, time_to, days, options.merge({product_code: self.code}))
        end

        #
        # Calculate the unit cost for a date and a number of days
        # ==Parameters:
        # date_from:: 
        #   The reservation starting date
        # ndays:: 
        #   Number of days
        # mode:: 
        #   Calculation mode: :first_season_day or :season_days_average
        # sales_channel_code::
        #   The sales channel code
        #
        # ==Returns:
        # A Number that represents the category price for the number of days starting from date
        #
        def unit_price(date_from, ndays, mode=nil, sales_channel_code=nil)
          
          unit_price_definition = self.price_definition

          # Get the price definition from the sales channel booking category (in case there is a price definition for it)
          if sales_channel_code
            if unit_price_bc_sales_channel = ::Yito::Model::Booking::BookingCategoriesSalesChannel.first(:booking_category_code => self.code,
                                                                                                         'sales_channel.code'.to_sym => sales_channel_code )
              unit_price_definition = unit_price_bc_sales_channel.price_definition if unit_price_bc_sales_channel.price_definition
            end
          end

          # Calculate the price using the price_definition
          if unit_price_definition
            if mode.nil?
              mode = SystemConfiguration::Variable.get_value('booking.renting_calendar_season_mode',
                                                             'first_day')
              mode = (mode == 'first_day' ? :first_season_day : :season_days_average)
            end
            unit_price_definition.calculate_price(date_from.to_date, ndays, mode)
          else
            return 0
          end
        
        end
        
        #
        # Count the defined (active and assignable) stock 
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
          !price_definition.nil?
        end
        
        #
        # Ready warnings
        #
        def ready_warnings
          warnings = []
          warnings << BookingDataSystem.r18n.t.code_empty if code.nil? or code.empty?
          warnings << BookingDataSystem.r18n.t.name_empty if name.nil? or name.empty?
          warnings << BookingDataSystem.r18n.t.price_definition_empty if price_definition.nil?
          return warnings
        end
        
        alias_method :ready, :ready?
        
        
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