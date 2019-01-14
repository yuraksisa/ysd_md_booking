module Yito
  module Model
    module Booking
      module Concerns
        module Insurance	
 
		    def self.included(model)

		        model.property :insurance_valid, DataMapper::Property::Boolean, default: true 
		        model.property :insurance_start_date, Date
		        model.property :insurance_end_date, Date
		        model.property :insurance_company, String, length: 50
		        model.property :insurance_policy_number, String, length: 50
		     
		        #
		        # Insurance end date warning
		        #
		        # == Parameters::
		        #
		        # days:: The number of days remaining to end date to consider it's a warning
		        #
		        #
		        def insurance_end_date_warning(days=30)
		        	today = Date.today
		        	insurance_end_date ? (insurance_end_date - today).numerator < days : true
		        end	

		    end

        end
      end
    end
  end
end        	
