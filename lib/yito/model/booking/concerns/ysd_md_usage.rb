module Yito
  module Model
    module Booking
      module Concerns
        module Usage	
 
		    def self.included(model)

		    	model.property :usage_units, Integer, default: 0
		     
		    end

        end
      end
    end
  end
end        	
