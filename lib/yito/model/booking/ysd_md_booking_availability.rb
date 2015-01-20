require 'singleton'
require 'ysd_md_calendar' unless defined?Yito::Model::Calendar::Calendar
module Yito
  module Model
  	module Booking
      #
      # Check availability
      #
  	  class Availability
        include Singleton
        
        #
        # Check the availability
        #
  	  	def categories_available(from, to)

          categories_with_calendar = ::Yito::Model::Booking::BookingCategory.all.select { |cat| not cat.calendar.nil? }

          calendars = categories_with_calendar.map { |cat| {:code => cat.code, :calendar => cat.calendar.id} }

          no_available = ::Yito::Model::Calendar::EventType.first(:name => 'not_available')

          condition = Conditions::JoinComparison.new('$and',
           [Conditions::Comparison.new('event_type', '$eq', no_available),
            Conditions::JoinComparison.new('$or', 
              [Conditions::JoinComparison.new('$and', 
                 [Conditions::Comparison.new('from','$lte', from),
                  Conditions::Comparison.new('to','$gte', from)
                  ]),
               Conditions::JoinComparison.new('$and',
                 [Conditions::Comparison.new('from','$lte', to),
                  Conditions::Comparison.new('to','$gte', to)
                  ]),
               Conditions::JoinComparison.new('$and',
                 [Conditions::Comparison.new('from','$eq', from),
                  Conditions::Comparison.new('to','$eq', to)
                  ]),
               Conditions::JoinComparison.new('$and',
                 [Conditions::Comparison.new('from', '$gte', from),
                  Conditions::Comparison.new('to', '$lte', to)])               
              ]
            ),
            ]
          )

          not_available = Set.new(condition.build_datamapper(Yito::Model::Calendar::Event).all.map { |item| item.calendar.id }).to_a

          calendars.select! { |cal| not_available.index(cal[:calendar]) == nil }
          calendars.map { |cal| cal[:code] }
          #calendars - not_available

  	  	end	

        #
        # Check the categories that allow payment on a date range
        #
        def categories_payment_enabled(from, to)

           if SystemConfiguration::Variable.get_value('booking.payment', 'false').to_bool
              ::Yito::Model::Booking::BookingCategory.all.map { |item| item.code }
           else

              payment_enabled = ::Yito::Model::Calendar::EventType.first(:name => 'payment_enabled')

              condition = Conditions::JoinComparison.new('$and',
                [Conditions::Comparison.new('event_type', '$eq', payment_enabled),
                 Conditions::Comparison.new('from', '$lte', from),
                 Conditions::Comparison.new('to', '$gte', to)])

              cat_payment_available = Set.new(condition.build_datamapper(Yito::Model::Calendar::Event).all.map {|item| item.calendar.name}).to_a

           end

        end

  	  end
  	end
  end
end