module Yito
  module Model
    module Booking
      module BookingExternalInvoice
        def self.included(model)

          if model.respond_to?(:property)
            model.property :external_invoice_number, String, :length => 40
            model.property :external_invoice_date, DateTime
          end
          
        end  
      end
    end
  end
end  