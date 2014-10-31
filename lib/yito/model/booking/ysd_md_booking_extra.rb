require 'data_mapper' unless defined?DataMapper
require 'ysd_md_yito' unless defined?Yito::Model::Finder
require 'ysd_md_rates' unless defined?Yito::Model::Rates::PriceDefinition
require 'aspects/ysd-plugins_applicable_model_aspect' unless defined?Plugins::ApplicableModelAspect

module Yito
  module Model
    module Booking
  	
      #
      # It represents a booking extra 
      #
      class BookingExtra
        include DataMapper::Resource
        extend  Plugins::ApplicableModelAspect           # Extends the entity to allow apply aspects
        extend  Yito::Model::Finder

        storage_names[:default] = 'bookds_extras'

        property :code, String, :field => 'code', :length => 50, :key => true      
        property :name, String, :field => 'name', :length => 80
        property :description, Text, :field => 'description'
        property :max_quantity, Integer, :field => 'max_quantity'
        belongs_to :price_definition, 'Yito::Model::Rates::PriceDefinition', :required => false

        def save
          check_price_definition! if self.price_definition          
          super # Invokes the super class to achieve the chain of methods invoked       
        end

        private

        def check_price_definition!
          if self.price_definition and (not self.price_definition.saved?) and loaded = ::Yito::Model::Rates::PriceDefinition.get(self.price_definition.id)
            self.price_definition = loaded
          end
        end

      end

    end
  end
end