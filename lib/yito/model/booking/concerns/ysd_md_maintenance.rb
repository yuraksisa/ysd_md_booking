module Yito
  module Model
    module Booking
      module Concerns
        module Maintenance	
 
		    def self.included(model)

		        model.property :maintenance_external_revision_last_date, Date
		        model.property :maintenance_external_revision_last_units, Integer, default: 0
		        model.property :maintenance_external_revision_next_date, Date
		        model.property :maintenance_external_revision_next_units, Integer, default: 0

		        model.property :maintenance_official_revision_last_date, Date
		        model.property :maintenance_official_revision_last_ok, DataMapper::Property::Boolean, default: true 
		        model.property :maintenance_official_revision_next_date, Date
		     
		    end

        end
      end
    end
  end
end        	
