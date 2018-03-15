module Yito
  module Model
    module Booking
      #
      # Helpers to calculate the supplements and deposit based on reservation search attributes
      #
      # - date_from
      # - time_from
      # - date_to
      # - time_to
      # - pickup_place
      # - return_place
      #
      class RentingCalculator

        attr_reader :days, :date_to_price_calculation,
                    :time_from_cost, :time_to_cost,
                    :pickup_place_cost, :return_place_cost,
                    :age, :driving_license_years, :age_allowed, :age_cost, :age_deposit,
                    :age_apply_age_deposit_if_product_deposit,
                    :age_rule_id, :age_rule_description, :age_rule_text,
                    :supplements_cost, :valid, :error

        def initialize(date_from, time_from, date_to,
                       time_to, pickup_place=nil, return_place=nil,
                       driver_age_data=nil, custom_pickup_place=false, custom_return_place=false)

          # Item family
          @item_family = nil
          item_family_id = SystemConfiguration::Variable.get_value('booking.item_family', nil)
          @item_family =  ProductFamily.get(item_family_id) unless item_family_id.nil?

          # Date from/to and pick up and return place
          @date_from = date_from
          @time_from = time_from
          @date_to = date_to
          @time_to = time_to
          @pickup_place = pickup_place
          @return_place = return_place
          @custom_pickup_place = custom_pickup_place
          @custom_return_place = custom_return_place

          @days = 0
          @date_to_price_calculation = date_to
          @time_from_cost = BigDecimal.new("0")
          @time_to_cost = BigDecimal.new("0")
          @pickup_place_cost = BigDecimal.new("0")
          @return_place_cost = BigDecimal.new("0")
          @supplements_cost = BigDecimal.new("0")
          @deposit = BigDecimal.new("0")

          @valid = true
          @error = nil

          # Driver age
          @driver_age_mode = @driver_age_rule = @driver_date_of_birth = @driver_driving_license_date = @age =
          @driving_license_years = nil

          if !driver_age_data.nil? and driver_age_data.is_a?(Hash)
            @driver_age_mode = driver_age_data[:driver_age_mode]
            @driver_age_rule = driver_age_data[:driver_age_rule]
            @driver_age_rule_definition = driver_age_data[:driver_age_rule_definition]
            @date_of_birth = driver_age_data[:driver_date_of_birth]
            @driver_driving_license_date = driver_age_data[:driver_driving_license_date]
            @age = BookingDataSystem::Booking.completed_years(@date_from, @date_of_birth) unless @date_of_birth.nil?
            @driving_license_years = BookingDataSystem::Booking.completed_years(@date_from, @driver_driving_license_date) unless @driver_driving_license_date.nil?
          end

          @age_allowed = true
          @age_cost = BigDecimal.new("0")
          @age_deposit = BigDecimal.new("0")
          @age_apply_age_deposit_if_product_deposit = false
          @age_rule_id = nil
          @age_rule_description = nil
          @age_rule_text = nil

          if !@item_family.nil?
            calculate_days
            calculate_time_from_to_cost if @valid && @item_family.pickup_return_place
            calculate_pickup_return_place_cost if @valid && @item_family.pickup_return_place
            calculate_driver_age_cost if !driver_age_data.nil? and @valid and @item_family.driver and
                                         SystemConfiguration::Variable.get_value('booking.driver_min_age.rules', 'false').to_bool
            @supplements_cost = @time_from_cost + @time_to_cost + @pickup_place_cost + @return_place_cost + @age_cost
            @deposit = @age_deposit
          else
            @valid = false
            @error = "Booking item family is not setup"
          end

        end

        def as_json(options={})

          {
              days: @days,
              date_to_price_calculation: @date_to_price_calculation,
              time_from_cost: @time_from_cost,
              time_to_cost: @time_to_cost,
              pickup_place_cost: @pickup_place_cost,
              return_place_cost: @return_place_cost,
              age: @age,
              driving_license_years: @driving_license_years,
              age_allowed: @age_allowed,
              age_cost: @age_cost,
              age_deposit: @age_deposit,
              age_apply_age_deposit_if_product_deposit: @age_apply_age_deposit_if_product_deposit,
              age_rule_id: @age_rule_id,
              age_rule_description: @age_rule_description,
              age_rule_text: @age_rule_text,
              valid: @valid,
              error: @error
          }

        end

        def to_json(*options)
          as_json(*options).to_json(*options)
        end

        private

        #
        # Calculate the reservation days
        #
        def calculate_days

          cadence_hours = SystemConfiguration::Variable.get_value('booking.hours_cadence',2).to_i
          @days = (@date_to - @date_from).to_i
          @date_to_price_calculation = @date_to
          begin
            _t_from = DateTime.strptime(@time_from,"%H:%M")
            _t_to = DateTime.strptime(@time_to,"%H:%M")
            if _t_to > _t_from
              hours_of_difference = (_t_to - _t_from).to_f.modulo(1) * 24
              if hours_of_difference > cadence_hours
                @days += 1
                @date_to_price_calculation += 1
              end
            end
          rescue
            @valid = false
            @error = "Time from or time to are not valid #{@time_from} #{@time_to}"
          end

        end

        #
        # Calculate time from/to cost
        #
        def calculate_time_from_to_cost
          time_cost = SystemConfiguration::Variable.get_value('booking.pickup_return_timetable_out_price', '0')
          if time_cost != '0'
            time_cost = BigDecimal.new(time_cost)
            timetable_id = SystemConfiguration::Variable.get_value('booking.pickup_return_timetable','0').to_i
            if timetable_id > 0
              if timetable = ::Yito::Model::Calendar::Timetable.get(timetable_id)
                @time_from_cost = calculate_time_cost(@date_from, @time_from, time_cost, timetable)
                @time_to_cost = calculate_time_cost(@date_to, @time_to, time_cost, timetable)
              end
            end
          end
        end

        #
        # Calculate pickup/return place cost
        #
        def calculate_pickup_return_place_cost
          custom_pickup_return_place_cost = BigDecimal.new(SystemConfiguration::Variable.get_value('booking.custom_pickup_return_place_price', '0'))

          pickup_return_place_def_id = SystemConfiguration::Variable.get_value('booking.pickup_return_place_definition','0').to_i
          pickup_return_place_def = nil
          if pickup_return_place_def_id > 0
            pickup_return_place_def = PickupReturnPlaceDefinition.get(pickup_return_place_def_id)
          end
          pickup_return_place_def = PickupReturnPlaceDefinition.first if pickup_return_place_def.nil?

          @pickup_place_cost = calculate_place_cost(@pickup_place, @custom_pickup_place, 'pickup', pickup_return_place_def,
                                                    custom_pickup_return_place_cost) if !@pickup_place.nil? && !@pickup_place.empty?

          @return_place_cost = calculate_place_cost(@return_place, @custom_return_place, 'return', pickup_return_place_def,
                                                    custom_pickup_return_place_cost) if !@return_place.nil? && !@return_place.empty?

        end

        #
        # Calculates the driver age cost
        #
        def calculate_driver_age_cost

          case @driver_age_mode

            when :rule
              if @driver_age_rule
                @age_allowed = @driver_age_rule.allowed
                @age_cost = @driver_age_rule.suplement * @days
                @age_deposit = @driver_age_rule.deposit
                @age_apply_age_deposit_if_product_deposit = @driver_age_rule.apply_if_product_deposit
                @age_rule_id = @driver_age_rule.id
                @age_rule_description = @driver_age_rule.description.first
                @age_rule_text = @driver_age_rule.to_json
              else
                @valid = false
                @error = 'Not a valid driver age rule'
              end
            when :dates
              if @age and @driving_license_years
                rules = @driver_age_rule_definition.find_rule(@age, @driving_license_years)
                if rules.size > 0
                  driver_age_rule = rules.first
                  @age_allowed = driver_age_rule.allowed
                  @age_cost = driver_age_rule.suplement * @days
                  @age_deposit = driver_age_rule.deposit
                  @age_apply_age_deposit_if_product_deposit = driver_age_rule.apply_if_product_deposit
                  @age_rule_id = driver_age_rule.id
                  @age_rule_description = driver_age_rule.description.first
                  @age_rule_text = driver_age_rule.to_json
                else
                  @valid = false
                  @error = 'Not a matching rule for driver age'
                end
              end
            else
              @valid = false
              @error = 'Driver age mode not valid. Allowed :rule or :dates'
          end

        end

        # --------------------------------------------------------------------------------------------------------

        #
        # Calculate time cost
        #
        def calculate_time_cost(date, time, time_cost, timetable)

          price = BigDecimal.new("0")
          day = date.wday
          time_parts = time.split(':')
          if time_parts.size == 2
            time_parts[0] = time_parts.first.rjust(2, '0')
            time = time_parts.join(':')
            case day
              when 0
                price = time_cost if !timetable.timetable_sunday ||
                                      time < timetable.timetable_sunday_from  ||
                                      time > timetable.timetable_sunday_to
              when 1
                price = time_cost if !timetable.timetable_monday ||
                                     time < timetable.timetable_monday_from  ||
                                     time > timetable.timetable_monday_to
              when 2
                price = time_cost if !timetable.timetable_monday ||
                                     time < timetable.timetable_tuesday_from  ||
                                     time > timetable.timetable_tuesday_to
              when 3
                price = time_cost if !timetable.timetable_monday ||
                                     time < timetable.timetable_wednesday_from  ||
                                     time > timetable.timetable_wednesday_to
              when 4
                price = time_cost if !timetable.timetable_monday ||
                                     time < timetable.timetable_thursday_from  ||
                                     time > timetable.timetable_thursday_to
              when 5
                price = time_cost if !timetable.timetable_monday ||
                                     time < timetable.timetable_friday_from  ||
                                     time > timetable.timetable_friday_to
              when 6
                price = time_cost if !timetable.timetable_monday ||
                                     time < timetable.timetable_saturday_from  ||
                                     time > timetable.timetable_saturday_to
            end

          else
            @valid = false
            @error = "Invalid time : #{time}"
          end

          return price

        end

        #
        # Calculate place cost
        #
        def calculate_place_cost(place, custom_place, mode,
                                 pickup_return_place_def,
                                 custom_pickup_return_place_cost)

            if custom_place
              return custom_pickup_return_place_cost
            else
              place = pickup_return_place_def.pickup_return_places.select { |item| item.name == place }.first
              if place
                if (mode == 'pickup' && place.is_pickup) || (mode == 'return' && place.is_return)
                  return place.price
                else
                  @valid = false
                  @error = 'The place is not a valid pickup place'
                end
              end
              return 0
            end

        end

      end
    end
  end
end