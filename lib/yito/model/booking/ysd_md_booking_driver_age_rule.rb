module Yito
  module Model
    module Booking
      #
      # Holds the booking driver age rule
      #
      class BookingDriverAgeRule
        include DataMapper::Resource

        extend  Yito::Model::Finder
        storage_names[:default] = 'bookds_driver_age_rules'

        property :id, Serial

        property :age_rule_type, Enum[:age, :driving_license_years, :both_age_driving_license_years], default: :both_age_driving_license_years
        property :join_conditions, Enum[:and, :or], default: :and

        property :age_condition, String, length: 4
        property :age_from, Integer, default: 0
        property :age_to, Integer, default: 0

        property :driving_license_years_condition, String, length: 4
        property :driving_license_years_from, Integer, default: 0
        property :driving_license_years_to, Integer, default: 0

        property :allowed, Boolean, default: true
        property :suplement, Decimal, scale: 2, precision: 10, default: 0
        property :deposit, Decimal, scale: 2, precision: 10, default: 0
        property :apply_if_product_deposit, Boolean, default: false
        property :rule_order, Integer, default: 0

        belongs_to :driver_age_rule_definition, 'BookingDriverAgeRuleDefinition', :child_key => [:driver_age_rule_definition_id], :parent_key => [:id]

        AGE_CONDITIONS = ['<','>','=','<->']
        DRIVING_LICENSE_YEARS_CONDITIONS = ['<','>','=','<->']

        def save
          check_driver_age_rule_definition! if self.driver_age_rule_definition
          super
        end

        #
        # Check if the age and driving license years math
        #
        def match(age, driving_license_years)

          result = true
          age_check = true
          driving_license_years_check = true

          # age
          if age_rule_type == :age or age_rule_type == :both_age_driving_license_years
            age_check = case age_condition
                           when '<'
                             age < age_from
                           when '>'
                             age > age_from
                           when '='
                             age == age_from
                           when '<->'
                             age >= age_from and age <= age_to
                           else
                             true
                        end
          end

          # driving license years
          if age_rule_type == :driving_license_years or age_rule_type == :both_age_driving_license_years
            driving_license_years_check = case driving_license_years_condition
                                            when '<'
                                               driving_license_years < driving_license_years_from
                                            when '>'
                                               driving_license_years > driving_license_years_from
                                            when '='
                                               driving_license_years == driving_license_years_from
                                            when '<->'
                                               driving_license_years >= driving_license_years_from and driving_license_years <= driving_license_years_to
                                            else
                                               true
                                          end
          end

          if age_rule_type == :both_age_driving_license_years
            if join_conditions == :and
              result = (age_check and driving_license_years_check)
            elsif join_conditions == :or
              result = (age_check or driving_license_years_check)
            end
          elsif age_rule_type == :age
            result = age_check
          elsif age_rule_type == :driving_license_years
            result = driving_license_years_check
          end

          return result
        end

        #
        # Textual description
        #
        def description(locale=nil)

          result = ['','']
          age_condition_literal = nil
          driving_license_years_literal = nil

          if age_rule_type == :age or age_rule_type == :both_age_driving_license_years
            age_condition_literal = case age_condition
                                      when '<'
                                        BookingDataSystem.r18n(locale).t.booking_driver_age.younger(age_from)
                                      when '>'
                                        BookingDataSystem.r18n(locale).t.booking_driver_age.older(age_from)
                                      when '='
                                        BookingDataSystem.r18n(locale).t.booking_driver_age.same_age(age_from)
                                      when '<->'
                                        BookingDataSystem.r18n(locale).t.booking_driver_age.between_age(age_from, age_to)
                                    end
          end

          if age_rule_type == :driving_license_years or age_rule_type == :both_age_driving_license_years
            driving_license_years_literal = case driving_license_years_condition
                                              when '<'
                                                BookingDataSystem.r18n(locale).t.booking_driver_age.less_driving_license(driving_license_years_from)
                                              when '>'
                                                BookingDataSystem.r18n(locale).t.booking_driver_age.more_driving_license(driving_license_years_from)
                                              when '='
                                                BookingDataSystem.r18n(locale).t.booking_driver_age.same_driving_license(driving_license_years_from)
                                              when '<->'
                                                BookingDataSystem.r18n(locale).t.booking_driver_age.between_driving_license(driving_license_years_from, driving_license_years_to)
                                            end
          end

          if age_rule_type == :both_age_driving_license_years
            if join_conditions == :and
              [BookingDataSystem.r18n(locale).t.booking_driver_age.driver_under_age_driving_license_literal(age_condition_literal, BookingDataSystem.r18n(locale).t.booking_driver_age.and_condition, driving_license_years_literal),
               allowed ? '' : BookingDataSystem.r18n(locale).t.booking_driver_age.driver_under_age_driving_license_not_authorized(age_condition_literal, BookingDataSystem.r18n(locale).t.booking_driver_age.and_condition, driving_license_years_literal)
              ]
            elsif join_conditions == :or
              [BookingDataSystem.r18n(locale).t.booking_driver_age.driver_under_age_driving_license_literal(age_condition_literal, BookingDataSystem.r18n(locale).t.booking_driver_age.or_condition, driving_license_years_literal),
               allowed ? '' : BookingDataSystem.r18n(locale).t.booking_driver_age.driver_under_age_driving_license_not_authorized(age_condition_literal, BookingDataSystem.r18n(locale).t.booking_driver_age.or_condition, driving_license_years_literal)
              ]
            end
          elsif age_rule_type == :age
            result = [BookingDataSystem.r18n(locale).t.booking_driver_age.driver_under_age_literal(age_condition_literal),
                      allowed ? '' : BookingDataSystem.r18n(locale).t.booking_driver_age.driver_under_age_not_authorized(age_condition_literal)]
          elsif age_rule_type == :driving_license_years
            result = [BookingDataSystem.r18n(locale).t.booking_driver_age.driver_driving_license_literal(driving_license_years_literal),
                      allowed ? '' : BookingDataSystem.r18n(locale).t.booking_driver_age.driver_driving_license_not_authorized(driving_license_years_literal)]
          end

        end

        private

        def check_driver_age_rule_definition!

          if self.driver_age_rule_definition and (not self.driver_age_rule_definition.saved?) and loaded = BookingDriverAgeRuleDefinition.get(self.driver_age_rule_definition.id)
            self.driver_age_rule_definition = loaded
          end

        end

      end

    end
  end
end
