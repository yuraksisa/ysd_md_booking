module Yito
  module Model
    module Booking
      class BookingCatalogExtra
        include DataMapper::Resource

        storage_names[:default] = 'bookds_catalog_extras'

        belongs_to :booking_catalog, 'BookingCatalog', :key => true
        belongs_to :booking_extra, 'BookingExtra', :key => true

        def save
          check_booking_catalog! if booking_catalog
          check_booking_extra! if booking_extra
          super
        end

        private

        def check_booking_catalog!
          if self.booking_catalog and (not self.booking_catalog.saved?) and loaded = BookingCatalog.get(self.booking_catalog.code)
            self.booking_catalog = loaded
          end        
        end

        def check_booking_extra!
          if self.booking_extra and (not self.booking_extra.saved?) and loaded = BookingExtra.get(self.booking_extra.code)
            self.booking_extra = loaded
          end           
        end

      end
    end
  end
end