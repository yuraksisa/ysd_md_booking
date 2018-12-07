require 'data_mapper' unless defined?DataMapper
require 'ysd_md_yito' unless defined?Yito::Model::Finder

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

        belongs_to :rental_storage, 'RentalStorage', child_key: [:rental_storage_id], parent_key: [:id], required: false
        has n, :rental_location_users, 'RentalLocationUser', child_key: [:rental_location_code], parent_key: [:code]
        belongs_to :address, 'LocationDataSystem::Address', :required => false 

        #
        # Exporting to json
        #
        def as_json(options={})

          if options.has_key?(:only)
            super(options)
          else
            relationships = options[:relationships] || {}
            relationships.store(:rental_location_users, {})
            super(options.merge({:relationships => relationships}))
          end

        end

      end
    end
  end
end