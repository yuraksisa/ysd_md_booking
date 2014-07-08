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

          categories = ::Yito::Model::Booking::BookingCategory.all.map { |cat| cat.code }

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
                  ])               
              ]
            ),
            ]
          )

          not_available = Set.new(condition.build_datamapper(Yito::Model::Calendar::Event).all.map { |item| item.calendar.name }).to_a

          categories - not_available

  	  	end	

  	  end
  	end
  end
end