module Yito
  module Model
    module Booking
      module BookingExternalInvoice
        def self.included(model)

          if model.respond_to?(:property)
            model.property :external_invoice_number, String, :length => 40
          end
          
        end  
      end
    end
  end
end  