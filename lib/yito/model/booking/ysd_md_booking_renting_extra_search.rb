module Yito
  module Model
  	module Booking
			#
			# Search extras and prices
			#
  	  class RentingExtraSearch

  	     attr_reader :code, :name, :description, :photo_path, :photo_full_path,
  	     			 :max_quantity, :stock, :unit_price
  	     
  	     def initialize(code, name, description, photo_path, photo_full_path,
  	     				max_quantity, unit_price,
				        stock, busy, available)

  	     	@code = code
  	     	@name = name
  	     	@description = description
					@photo_path = photo_path
					@photo_full_path = photo_full_path
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
						photo_path: @photo_path,
						photo_full_path: @photo_full_path,
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

				 domain = SystemConfiguration::Variable.get_value('site.domain')

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

								# Get the photos
								photo = item.album ? item.album.thumbnail_medium_url : nil
								full_photo = item.album ? item.album.image_url : nil
								photo_path = nil
								if photo
									photo_path = (photo.match(/^https?:/) ? photo : File.join(domain, photo))
								end
								full_photo_path = nil
								if full_photo
									full_photo_path = (full_photo.match(/^https?:/) ? full_photo : File.join(domain, full_photo))
								end

  		   				# Get the unit price
  		   				unit_price = item.unit_price(from, days)

								# Get the availability
								stock = occupation_hash.has_key?(item.code) ? occupation_hash[item.code][:stock] : 0
								busy = occupation_hash.has_key?(item.code) ? occupation_hash[item.code][:busy] : 0
								available = (stock > busy)

  		   				# Build the search result
  		   				RentingExtraSearch.new(item.code, item.name, item.description, photo_path, full_photo_path,
  		   					item.max_quantity, unit_price, stock, busy, available)
  		   			end

  		   return extra_code.nil? ? result : result.first	      		   			

  		 end    	 

  	  end
  	end
  end
end	