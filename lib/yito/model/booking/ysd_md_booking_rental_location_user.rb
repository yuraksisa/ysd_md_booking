require 'data_mapper' unless defined?DataMapper
require 'ysd_md_yito' unless defined?Yito::Model::Finder

module Yito
  module Model
    module Booking
      #
      # It represents a rental location - user association
      #
      class RentalLocationUser
        include DataMapper::Resource
        extend  Yito::Model::Finder

        storage_names[:default] = 'bookds_rental_location_users'

        belongs_to :rental_location, 'RentalLocation', key: true
        belongs_to :user, 'Users::Profile', key: true

        def save
          check_rental_location! if rental_location
          check_user! if user
          super
        end

        private

        def check_rental_location!
          if self.rental_location and (not self.rental_location.saved?) and loaded = RentalLocationUser.get(self.rental_location.code)
            self.rental_location = loaded
          end
        end

        def check_user!
          if self.user and (not self.user.saved?) and loaded = Users::Profile.get(self.user.username)
            self.user = loaded
          end
        end

      end
    end
  end
end