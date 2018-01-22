module Yito
  module Model
    module Booking
      module SupplementsCalculation

        #
        # Calculate supplements (time to/from, pickup/return place, driver age)
        #
        def calculate_supplements

          # Calculate the new price of the reservation
          driver_age_data = build_driver_age_data
          calculator = RentingCalculator.new(self.date_from, self.time_from,
                                             self.date_to, self.time_to,
                                             self.pickup_place, self.return_place,
                                             driver_age_data)

          # days
          self.days = calculator.days
          self.date_to_price_calculation = calculator.date_to_price_calculation

          # driver information
          if driver_age_data
            assign_calculator_driver_data(calculator)
          end

          # time_from supplement
          self.time_from_cost = calculator.time_from_cost
          # time_to supplement
          self.time_to_cost = calculator.time_to_cost
          # pickup_place supplement
          self.pickup_place_cost = calculator.pickup_place_cost
          # return_place_supplement
          self.return_place_cost = calculator.return_place_cost
          # driver supplement
          self.driver_age_cost = calculator.age_cost

        end

        #
        # Calculate (just) driver supplement
        #
        def calculate_driver_supplement

          # Calculate the new price of the reservation
          driver_age_data = build_driver_age_data
          calculator = RentingCalculator.new(self.date_from, self.time_from,
                                             self.date_to, self.time_to,
                                             self.pickup_place, self.return_place,
                                             driver_age_data)

          # driver information
          assign_calculator_driver_data(calculator)

          # driver supplement
          self.driver_age_cost = calculator.age_cost

        end

        #
        # Build driver age data
        #
        def build_driver_age_data

          driver_rule = nil
          driver_age_data = nil

          if self.driver_date_of_birth and self.driver_driving_license_date
            self.driver_age = BookingDataSystem::Booking.completed_years(self.date_from, self.driver_date_of_birth) if self.driver_age.nil?
            self.driver_driving_license_years = BookingDataSystem::Booking.completed_years(self.date_from, self.driver_driving_license_date) if self.driver_driving_license_years.nil?
            if driver_rule_definition_id = SystemConfiguration::Variable.get_value('booking.driver_min_age.rule_definition')
              if driver_rule_definition = ::Yito::Model::Booking::BookingDriverAgeRuleDefinition.get(driver_rule_definition_id)
                driver_rule = driver_rule_definition.find_rule(self.driver_age, self.driver_driving_license_years)
                driver_age_data = {
                                    driver_age_mode: :dates,
                                    driver_date_of_birth: self.driver_date_of_birth,
                                    driver_driving_license_date: self.driver_driving_license_date,
                                    driver_age_rule_definition: driver_rule_definition
                                  }
              end
            end
          elsif self.driver_age_rule_id
            if driver_rule = ::Yito::Model::Booking::BookingDriverAgeRule.get(driver_age_rule_id)
              driver_age_data = {
                                  driver_age_mode: :rule,
                                  driver_age_rule: driver_rule
                                }
            end
          end

          return driver_age_data

        end

        #
        # Assign calculator driver data
        #
        def assign_calculator_driver_data(calculator)
          self.driver_age = calculator.age if calculator.age
          self.driver_driving_license_years = calculator.driving_license_years if calculator.driving_license_years
          self.driver_age_allowed = calculator.age_allowed
          self.driver_under_age = !calculator.age_allowed
          self.driver_age_rule_id = calculator.age_rule_id
          self.driver_age_rule_description = calculator.age_rule_description
          self.driver_age_rule_text = calculator.age_rule_text
          self.driver_age_rule_apply_if_prod_deposit = calculator.age_apply_age_deposit_if_product_deposit
          self.driver_age_rule_deposit = calculator.age_deposit
        end

      end
    end
  end
end