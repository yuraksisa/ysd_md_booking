module Yito
  module Model
    module Booking
      module CostCalculation

        #
        # Calculate cost
        #
        # @param calculate_supplements Indicate if should be calculated the supplements
        # @param calculate_depoist Indicate if should be calculated deposit
        #
        def calculate_cost(calculate_supplements, calculate_deposit)

          self.calculate_supplements if calculate_supplements # Calculate pickup, return place and time supplements + driver age supplements...
          self.calculate_deposit if calculate_deposit         # Calculate product and driver age deposits

          # Reset total cost
          self.total_cost = 0

          # Add product cost
          self.total_cost = self.item_cost

          # Add extras cost
          self.total_cost += self.extras_cost

          # Apply supplements (time and places)
          self.total_cost += self.time_from_cost
          self.total_cost += self.time_to_cost
          self.total_cost += self.pickup_place_cost
          self.total_cost += self.return_place_cost
          self.total_cost += self.driver_age_cost

          # Apply category supplements
          self.total_cost += category_supplement_1_cost
          self.total_cost += category_supplement_2_cost
          self.total_cost += category_supplement_3_cost

          # Apply other supplements
          self.total_cost += supplement_1_cost
          self.total_cost += supplement_2_cost
          self.total_cost += supplement_3_cost

          # Total cost before deposit 
          total_cost_before_deposit = self.total_cost

          # Apply deposit
          self.total_cost_includes_deposit = SystemConfiguration::Variable.get_value('booking.total_cost_includes_deposit', 'false').to_bool
          if self.total_cost_includes_deposit
            self.total_cost += self.total_deposit
          end

          self.total_pending = self.total_cost - self.total_paid if defined?self.total_pending and defined?self.total_paid

          # Calculate booking amount : recommended amount to confirm the reservation
          deposit_percentage = SystemConfiguration::Variable.get_value('booking.deposit', '0').to_i
          if deposit_percentage > 0
            self.booking_amount_includes_deposit = SystemConfiguration::Variable.get_value('booking.booking_amount_includes_deposit', 'true').to_bool
            if self.booking_amount_includes_deposit
              self.booking_amount = ((total_cost_before_deposit + self.total_deposit) * deposit_percentage / 100).round
            else
              self.booking_amount = (total_cost_before_deposit * deposit_percentage / 100).round
            end
          end

        end

      end
    end
  end
end