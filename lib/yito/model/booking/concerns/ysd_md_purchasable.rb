module Yito
  module Model
    module Booking
      module Concerns
        module Purchasable	
 
		    def self.included(model)

		        model.property :purchasable_year, Integer, default: 0
		        model.property :purchasable_adquisition_date, Date
		        model.property :purchasable_purchase_price, DataMapper::Property::Decimal, :scale => 2, :precision => 10, :default => 0
		        model.property :purchasable_purchase_units, Integer, default: 0
		        model.property :purchasable_sold_release_date, Date
		        model.property :purchasable_sale_price,  DataMapper::Property::Decimal, :scale => 2, :precision => 10, :default => 0
		     
		    end

        end
      end
    end
  end
end        	
