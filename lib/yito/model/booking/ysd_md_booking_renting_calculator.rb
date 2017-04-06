module Yito
  module Model
    module Booking
      #
      # Helpers to calculate booking reservation information
      #
      class RentingCalculator

        attr_reader :days, :date_to_price_calculation,
                    :time_from_cost, :time_to_cost,
                    :pickup_place_cost, :return_place_cost,
                    :age, :age_cost, :age_valid, :supplements_cost, :valid, :error

        def initialize(date_from, time_from, date_to,
                       time_to, pickup_place=nil, return_place=nil,
                       date_of_birth=nil)

          @date_from = date_from
          @time_from = time_from
          @date_to = date_to
          @time_to = time_to
          @pickup_place = pickup_place
          @return_place = return_place
          @date_of_birth = date_of_birth
          @age = age_in_completed_years unless date_of_birth.nil?

          @days = 0
          @date_to_price_calculation = date_to
          @time_from_cost = BigDecimal.new("0")
          @time_to_cost = BigDecimal.new("0")
          @pickup_place_cost = BigDecimal.new("0")
          @return_place_cost = BigDecimal.new("0")
          @age_cost = BigDecimal.new("0")
          @age_valid = true
          @supplements_cost = BigDecimal.new("0")

          @valid = true
          @error = nil

          @item_family = nil
          item_family_id = SystemConfiguration::Variable.get_value('booking.item_family', nil)
          unless item_family_id.nil?
            @item_family =  ProductFamily.get(item_family_id)
          end

          if @item_family.driver
            @min_age = SystemConfiguration::Variable.get_value('booking.driver_min_age', '0').to_i
            @min_age_allowed = SystemConfiguration::Variable.get_value('booking.driver_min_age.allowed', 'false').to_bool
            @min_age_cost = BigDecimal.new(SystemConfiguration::Variable.get_value('booking.driver_min_age.cost', '99'))
          end

          if !@item_family.nil?
            calculate_days
            calculate_time_from_to_cost if @valid && @item_family.pickup_return_place
            calculate_pickup_return_place_cost if @valid && @item_family.pickup_return_place
            @age_valid = check_age_valid if @valid && @item_family.driver && !@date_of_birth.nil?
            @age_cost = calculate_age_cost if @valid && @item_family.driver && !@date_of_birth.nil?
            @supplements_cost = @time_from_cost + @time_to_cost + @pickup_place_cost + @return_place_cost + @age_cost
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
              age_cost: @age_cost,
              age_valid: @age_valid,
              valid: @valid,
              error: @error
          }

        end

        def to_json(*options)
          as_json(*options).to_json(*options)
        end

        private

        #
        # Calculate the age
        #
        def age_in_completed_years
          d = DateTime.now
          a = d.year - @date_of_birth.year
          a = a - 1 if (@date_of_birth.month > d.month or
                       (@date_of_birth.month >= d.month and @date_of_birth.day > d.day))
          a
        end

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
          allow_custom_pickup_return_places = SystemConfiguration::Variable.get_value('booking.allow_custom_pickup_return_place','false').to_bool
          custom_pickup_return_place_cost = SystemConfiguration::Variable.get_value('booking.custom_pickup_return_place_price', '0')
          custom_pickup_return_place_cost = BigDecimal.new(custom_pickup_return_place_cost)
          pickup_return_place_def_id = SystemConfiguration::Variable.get_value('booking.pickup_return_place_definition','0').to_i
          pickup_return_place_def = nil
          if pickup_return_place_def_id > 0
            pickup_return_place_def = PickupReturnPlaceDefinition.get(pickup_return_place_def_id)
          end
          pickup_return_place_def = PickupReturnPlaceDefinition.first if pickup_return_place_def.nil?

          @pickup_place_cost = calculate_place_cost(@pickup_place, 'pickup', pickup_return_place_def,
                                                    allow_custom_pickup_return_places, custom_pickup_return_place_cost) if !@pickup_place.nil? && !@pickup_place.empty?
          @return_place_cost = calculate_place_cost(@return_place, 'return', pickup_return_place_def,
                                                    allow_custom_pickup_return_places, custom_pickup_return_place_cost) if !@return_place.nil? && !@return_place.empty?
        end

        #
        # Check if age is valid
        #
        def check_age_valid
          if !@min_age_allowed && (@age < @min_age)
            return false
          end

          return true
        end

        #
        # Calculate age cost
        #
        def calculate_age_cost
          if @age < @min_age
            return @min_age_cost
          end

          return BigDecimal.new("0")
        end

        # --------------------------------------------------------------------------------------------------------

        #
        # Calculate time cost
        #
        def calculate_time_cost(date, time, time_cost, timetable)

          price = BigDecimal.new("0")
          day = date.day
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
                                     time > timetable.timetable_sunday_monday_to
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
        def calculate_place_cost(place, mode, pickup_return_place_def, allow_custom_pickup_return_places, custom_pickup_return_place_cost)

          place = pickup_return_place_def.pickup_return_places.select { |item| item.name == place }.first

          if place
            if (mode == 'pickup' && place.is_pickup) || (mode == 'return' && place.is_return)
              return place.price
            else
              @valid = false
              @error = 'The place is not a valid pickup place'
            end
          else
            return custom_pickup_return_place_cost if allow_custom_pickup_return_places
          end

          return 0

        end

      end
    end
  end
end