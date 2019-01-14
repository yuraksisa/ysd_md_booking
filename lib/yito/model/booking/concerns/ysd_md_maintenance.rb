module Yito
  module Model
    module Booking
      module Concerns
        module Maintenance	
 
		    def self.included(model)

		        model.property :maintenance_external_revision_last_date, Date
		        model.property :maintenance_external_revision_last_units, Integer, default: 0
		        model.property :maintenance_external_revision_last_comments, DataMapper::Property::Text
		        model.property :maintenance_external_revision_next_date, Date
		        model.property :maintenance_external_revision_next_units, Integer, default: 0

		        model.property :maintenance_official_revision_last_date, Date
		        model.property :maintenance_official_revision_last_ok, DataMapper::Property::Boolean, default: true 
		        model.property :maintenance_official_revision_last_comments, DataMapper::Property::Text
		        model.property :maintenance_official_revision_next_date, Date

		        #
		        # External revision warning
		        #
		        # == Parameters::
		        #
		        # days:: The number of days remaining to the next revision date to consider it's a warning
		        #
		        #
		        def maintenance_external_revision_warning(days=30)
		        	today = Date.today
		        	maintenance_external_revision_next_date ? (maintenance_external_revision_next_date - today).numerator < days : true
		        end	
		     
		        #
		        # Official revision warning
		        #
		        # == Parameters::
		        #
		        # days:: The number of days remaining to the next revision date to consider it's a warning
		        #
		        #
		        def maintenance_official_revision_warning(days=30)
		        	today = Date.today
		        	maintenance_official_revision_next_date ? (maintenance_official_revision_next_date - today).numerator < days : true
		        end	

		    end

        end
      end
    end
  end
end        	
