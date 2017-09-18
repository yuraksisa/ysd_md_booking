require 'data_mapper' unless defined?DataMapper
require 'ysd_md_yito' unless defined?Yito::Model::Finder
require 'ysd_md_calendar' unless defined?Yito::Model::Calendar::Calendar
require 'ysd_md_rates' unless defined?Yito::Model::Rates::PriceDefinition
require 'aspects/ysd-plugins_applicable_model_aspect' unless defined?Plugins::ApplicableModelAspect

module Yito
  module Model
    module Booking
      #
      # It represents a rent location (working center)
      #
      class RentalLocation
        include DataMapper::Resource
        extend  Yito::Model::Finder

        storage_names[:default] = 'bookds_rental_locations'

        property :code, String, length: 50, key: true
        property :name, String, length: 255

      end
    end
  end
end