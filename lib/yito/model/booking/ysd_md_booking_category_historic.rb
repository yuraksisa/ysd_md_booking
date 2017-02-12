require 'data_mapper' unless defined?DataMapper

module Yito
  module Model
    module Booking
      class BookingCategoryHistoric
        include DataMapper::Resource

        storage_names[:default] = 'bookds_categories_historics'

        belongs_to :category, 'Yito::Model::Booking::BookingCategory',
                   :child_key => [:category_code], :parent_key => [:code], :key => true
        property :year, Integer, :key => true

        property :stock, Integer, default: 0

      end
    end
  end
end