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

        #
        # Check if the age and driving license years math
        #
        def match(age, driving_license_years)
          result = true

          # age
          result = case age_condition
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

          if result
            # driving license years
            result = case driving_license_years_condition
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

          return result
        end

        #
        # Textual description
        #
        def description(locale=nil)

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

          if driving_license_years_condition.nil?
            [BookingDataSystem.r18n(locale).t.booking_driver_age.driver_under_age_literal(age_condition_literal),
             allowed ? '' : BookingDataSystem.r18n(locale).t.booking_driver_age.driver_under_age_not_authorized(age_condition_literal)]
          else
            [BookingDataSystem.r18n(locale).t.booking_driver_age.driver_under_age_driving_license_literal(age_condition_literal, driving_license_years_literal),
             allowed ? '' : BookingDataSystem.r18n(locale).t.booking_driver_age.driver_under_age_driving_license_not_authorized(age_condition_literal, driving_license_years_literal)
            ]
          end

        end

      end
    end
  end
end
