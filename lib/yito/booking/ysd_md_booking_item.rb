require 'data_mapper' unless defined?DataMapper
require 'ysd_md_yito' unless defined?Yito::Model::Finder
require 'aspects/ysd-plugins_applicable_model_aspect' unless defined?Plugins::ApplicableModelAspect

module Yito
  module Booking
  	
    #
    # It represents a booking item (something that can be booked)
    #
    class Item
      include DataMapper::Resource
      extend  Plugins::ApplicableModelAspect           # Extends the entity to allow apply aspects
      extend  Yito::Model::Finder

      storage_names[:default] = 'bookds_items'

      property :id, Serial, :field => 'code', :key => true      
      property :name, String, :field => 'name', :length => 80
      property :description, Text, :field => 'description'
      property :reference, String, :field => 'reference', :length => 80

    end
  end
end