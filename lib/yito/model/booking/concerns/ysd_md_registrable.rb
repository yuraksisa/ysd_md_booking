module Yito
  module Model
    module Booking
      module Concerns
        module Registrable	
 
		    def self.included(model)

		        model.property :registrable_registration_date, Date
		     
		    end

        end
      end
    end
  end
end        	
