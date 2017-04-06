module Yito
  module Model
  	module Booking
			#
			# Search extras and prices
			#
  	  class RentingExtraSearch

  	     attr_reader :code, :name, :description, 
  	     			 :max_quantity, :unit_price
  	     
  	     def initialize(code, name, description,
  	     				max_quantity, 
  	     				unit_price) 

  	     	@code = code
  	     	@name = name
  	     	@description = description
  	     	@max_quantity = max_quantity
  	     	@unit_price = unit_price

  	     end

  		 def as_json(options={})

  		 	   {code: @code,
  		 	   	name: @name,
  		 	   	description: @description,
  		 	   	max_quantity: @max_quantity,
  		 	   	unit_price: @unit_price
  				}

  		 end

  		 def to_json(*options)
       	   as_json(*options).to_json(*options)
    	 end

  		 #
  		 # Search extras and price
  		 #
  		 def self.search(from, to, days, extra_code=nil)

  		   # Query for products
  		   extra_attributes = [:code, :name, :description, :max_quantity]
  		   conditions = {active: true, web_public: true}
  		   conditions.store(:code, extra_code) unless extra_code.nil?

  		   result = ::Yito::Model::Booking::BookingExtra.all(fields: extra_attributes,
  		   			   conditions: conditions, 
  		   			   order: [:code]).map do |item| 
  		   				
  		   				# Get the unit price
  		   				unit_price = item.unit_price(from, days)
  		   				
  		   				# Build the search result
  		   				RentingExtraSearch.new(item.code, item.name, item.description,
  		   					item.max_quantity, unit_price)
  		   			end

  		   return extra_code.nil? ? result : result.first	      		   			

  		 end    	 

  	  end
  	end
  end
end	