require 'singleton'
module Yito
  module Model
  	module Booking
  	  class Generator  
  	    include Singleton

        def create_rates

          booking_catalogs = BookingCatalog.all

          if booking_catalogs.size > 0
            booking_catalogs.each do |booking_catalog|
              save_rates(booking_catalog.code, 
                         booking_catalog.rates_template_code, 
                         build_script(booking_catalog.code))
            end
          else
            save_rates(nil, 'booking_js', build_script(nil))
          end

        end

        def build_script(booking_catalog_code)
          
          booking_extras = BookingExtra.all
          booking_categories = booking_catalog_code ? 
                                 BookingCategory.all(:booking_catalog_code => booking_catalog_code) :
                                 BookingCategory.all
          season_definition = ::Yito::Model::Rates::SeasonDefinition.first
          factor_definition = ::Yito::Model::Rates::FactorDefinition.first
          place_definition = PickupReturnPlaceDefinition.first
          pickup_places = PickupReturnPlace.all(:place_definition_id => place_definition.id, :is_pickup => true)
          return_places = PickupReturnPlace.all(:place_definition_id => place_definition.id, :is_return => true)          

          template_file = File.expand_path(File.join(File.dirname(__FILE__), "..", "..", "..", "..",
             "templates", "booking.js.erb"))
          template = ERB.new File.read(template_file)
          message = template.result(binding)

        end

        private

        def save_rates(catalog_name, template_name, script)

          description = catalog_name ?
                        "Definición de los productos de alquiler y tarifas catálogo #{catalog_name}" :
                        "Definición de los productos de alquiler y tarifas"

          if booking_js=ContentManagerSystem::Template.find_by_name(template_name)
             booking_js.text = script
             booking_js.save
          else
             ContentManagerSystem::Template.create({:name => template_name, 
                :description => description,
                :text => script})
          end

        end

  	  end
  	end
  end
end