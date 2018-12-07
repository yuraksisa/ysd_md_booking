require 'data_mapper' unless defined?DataMapper
require 'ysd_md_yito' unless defined?Yito::Model::Finder

module Yito
  module Model
    module Booking
      #
      # It represents a rental storage or campa
      #
      class RentalStorage
        include DataMapper::Resource
        extend  Yito::Model::Finder

        storage_names[:default] = 'bookds_rental_storages'

        property :id, Serial
        property :name, String, length: 255

        belongs_to :address, 'LocationDataSystem::Address', :required => false 
        
        has n, :rental_locations, 'RentalLocation', child_key: [:rental_storage_id], parent_key: [:id]

        #
        # Exporting to json
        #
        def as_json(options={})

          if options.has_key?(:only)
            super(options)
          else
            relationships = options[:relationships] || {}
            relationships.store(:rental_locations, {})
            super(options.merge({:relationships => relationships}))
          end

        end

      end
    end
  end
end