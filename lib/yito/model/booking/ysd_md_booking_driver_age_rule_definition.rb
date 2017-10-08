module Yito
  module Model
    module Booking

      #
      # Holds the booking driver age rule definition
      #
      class BookingDriverAgeRuleDefinition
        include DataMapper::Resource

        extend  Yito::Model::Finder
        storage_names[:default] = 'bookds_driver_age_rule_defs'

        property :id, Serial
        property :name, String, length: 256

        has n, :driver_age_rules, 'BookingDriverAgeRule', :child_key => [:driver_age_rule_definition_id], :parent_key => [:id], :constraint => :destroy

        #
        # Find a rule that matches the driver age and driving license years
        #
        def find_rule(driver_age, driver_driving_license_years)
          driver_age_rules.select { |drive_age_rule| drive_age_rule.match(driver_age, driver_driving_license_years) }
        end

      end
    end
  end
end