module Yito
  module Model
    module Booking
      class BookingCatalog
        include DataMapper::Resource
        extend  Yito::Model::Finder

        storage_names[:default] = 'bookds_catalogs'

        property :code, String, :length => 20, :key => true 
        property :description, String, :length => 255
        property :selector, String, :length => 10
        belongs_to :product_family, 'ProductFamily'
        has n, :booking_catalog_extras, :child_key => [:booking_catalog_code], :parent_key => [:code], :constraint => :destroy
        has n, :booking_extras, :through => :booking_catalog_extras, :via => :booking_extra

        def rates_template_code
          "booking_tmpl_cat_#{code}_js"
        end 

        def destroy
          catalog_code = self.code
          super
          default_catalog_code = SystemConfiguration::Variable.get_value('booking.default_booking_catalog.code', nil)
          if default_catalog_code == catalog_code
            SystemConfiguration::Variable.set_value('booking.default_booking_catalog.code','')
          end 
        end

        def save
          check_product_family! if self.product_family
          check_booking_extras! if self.booking_extras and (not self.booking_extras.empty?)          
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
            relationships.store(:booking_extras, {})
            super(options.merge({:relationships => relationships}))
          end

        end

        private

        def check_product_family!

          if self.product_family and (not self.product_family.saved?) and loaded = ProductFamily.get(self.product_family.code)
            self.product_family = loaded
          end

        end        

        #
        # Preprocess the extras and loads if they exist
        #
        def check_booking_extras!
          self.booking_extras.map! do |be|
            if (not be.saved?) and loaded_booking_extra = BookingExtra.get(be.code)
              loaded_booking_extra
            else
              be
            end 
          end
        end

      end
    end
  end
end