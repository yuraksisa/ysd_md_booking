module Yito
  module Model
  	module Booking
			#
			# Search extras and prices
			#
  	  class RentingExtraSearch

  	     attr_reader :code, :name, :description, 
  	     			 :max_quantity, :stock, :unit_price
  	     
  	     def initialize(code, name, description,
  	     				max_quantity, unit_price,
				        stock, busy, available)

  	     	@code = code
  	     	@name = name
  	     	@description = description
  	     	@max_quantity = [max_quantity, stock-busy].min
  	     	@unit_price = unit_price
					@stock = stock
				  @busy = busy
					@available = available

  	     end

  		 def as_json(options={})

  		 	   {code: @code,
  		 	   	name: @name,
  		 	   	description: @description,
  		 	   	max_quantity: @max_quantity,
						stock: @stock,
  		 	   	unit_price: @unit_price
  				}

  		 end

  		 def to_json(*options)
       	   as_json(*options).to_json(*options)
    	 end

  		 #
  		 # Search extras and price
  		 #
  		 def self.search(from, to, days, locale=nil, extra_code=nil)

				 # Check the 'real' occupation
				 occupation = BookingDataSystem::Booking.extras_occupation(from, to).map do |item|
					 {extra_id: item.extra_id, stock: item.stock, busy: item.busy}
				 end
				 occupation_hash = occupation.inject({}) do |result,item|
					 result.store(item[:extra_id], item.select {|key,value| key != :extra_id})
					 result
				 end

  		   # Query for products
  		   extra_attributes = [:code, :name, :description, :max_quantity, :stock]
  		   conditions = {active: true, web_public: true}
  		   conditions.store(:code, extra_code) unless extra_code.nil?

  		   result = ::Yito::Model::Booking::BookingExtra.all(fields: extra_attributes,
  		   			   conditions: conditions, 
  		   			   order: [:code]).map do |item|

					      # Translate the extra
					      item = item.translate(locale) if locale 
					 
  		   				# Get the unit price
  		   				unit_price = item.unit_price(from, days)

								# Get the availability
								stock = occupation_hash.has_key?(item.code) ? occupation_hash[item.code][:stock] : 0
								busy = occupation_hash.has_key?(item.code) ? occupation_hash[item.code][:busy] : 0
								available = (stock > busy)

  		   				# Build the search result
  		   				RentingExtraSearch.new(item.code, item.name, item.description,
  		   					item.max_quantity, unit_price, stock, busy, available)
  		   			end

  		   return extra_code.nil? ? result : result.first	      		   			

  		 end    	 

  	  end
  	end
  end
end	