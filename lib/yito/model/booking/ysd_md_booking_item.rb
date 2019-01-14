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
        property :stock_model, String, :length => 80
        property :stock_plate, String, :length => 80
        property :characteristic_1, String, :length => 80
        property :characteristic_2, String, :length => 80
        property :characteristic_3, String, :length => 80
        property :characteristic_4, String, :length => 80
        property :cost, Decimal, :scale => 2, :precision => 10 
        property :active, Boolean, :default => true
        property :own_property, Boolean, :default => true
        property :assignable, Boolean, :default => true
        property :planning_order, Integer, :default => 0   
        belongs_to :category, 'Yito::Model::Booking::BookingCategory', 
          :child_key => [:category_code], :parent_key => [:code]
        belongs_to :rental_storage, 'RentalStorage', child_key: [:rental_storage_id], parent_key: [:id], required: false  

        include ::Yito::Model::Booking::Concerns::Registrable
        include ::Yito::Model::Booking::Concerns::Purchasable
        include ::Yito::Model::Booking::Concerns::Usage
        include ::Yito::Model::Booking::Concerns::Maintenance
        include ::Yito::Model::Booking::Concerns::Insurance

        #
        # Override the save method to check the category
        #
        def save
          check_category! if self.category
          super
        end

        #
        # Change the reference
        #
        # == Parameters:
        #
        # new_reference:: New reference
        #
        def change_reference(new_reference)

          # In datamapper it's not possible to update the key value, so we use adapter
          # https://stackoverflow.com/questions/32302407/updating-a-property-set-as-the-key-in-datamapper
          BookingItem.change_item_reference(new_reference, reference)
          # Update the item references assigned
          BookingDataSystem::BookingLineResource.all(booking_item_reference: reference).update(booking_item_reference: new_reference)
          # Update stock locking references
          BookingDataSystem::BookingPrereservationLine.all(booking_item_reference: reference).update(booking_item_reference: new_reference)

        end

        #
        # Exporting to json
        #
        def as_json(options={})

          if options.has_key?(:only)
            super(options)
          else
            relationships = options[:relationships] || {}
            relationships.store(:rental_storage, {})
            methods = options[:methods] || []
            methods << :maintenance_external_revision_warning
            methods << :maintenance_official_revision_warning
            methods << :insurance_end_date_warning
            super(options.merge({relationships: relationships, methods: methods}))
          end

        end

        private

        #
        # Update the item reference
        #
        # == Parameters::
        #
        # new_reference:: The new reference
        # reference:: Current reference
        #
        def self.change_item_reference(new_reference, reference)
          query = <<-QUERY
            update bookds_items set reference = ? where reference = ?
          QUERY
          repository.adapter.select(query, new_reference, reference)
        end

        #
        # Check the category on save
        #
        def check_category!
          if self.category and (not self.category.saved?) and loaded = BookingCategory.get(self.category.code)
            self.category = loaded
          end
          if self.rental_storage and (not self.rental_storage.saved?) and loaded = RentalStorage.get(self.rental_storage.id)
            self.rental_storage = loaded
          end
        end

      end

    end
  end
end
