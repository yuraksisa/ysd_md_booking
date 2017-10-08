module Yito
  module Model
    module Booking
      module DepositCalculation

        #
        # Calculate the deposit
        #
        def calculate_deposit

          self.total_deposit = product_deposit_cost

          booking_item_family = ::Yito::Model::Booking::ProductFamily.get(SystemConfiguration::Variable.get_value('booking.item_family'))

          if booking_item_family and booking_item_family.driver
            booking_driver_min_age_rules = SystemConfiguration::Variable.get_value('booking.driver_min_age.rules','false').to_bool
            if booking_driver_min_age_rules
              if self.product_deposit_cost == 0 or (self.driver_age_rule_apply_if_prod_deposit and self.driver_age_rule_deposit > 0)
                self.driver_age_deposit = self.driver_age_rule_deposit
                self.total_deposit += self.driver_age_deposit
              else
                self.driver_age_deposit = 0
              end
            end
          end

        end

      end
    end
  end
end