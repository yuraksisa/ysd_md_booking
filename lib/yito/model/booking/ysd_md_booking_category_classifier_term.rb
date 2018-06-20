module Yito
  module Model
    module Booking
      class CategoryClassifierTerm
        include DataMapper::Resource

        storage_names[:default] = 'bookds_category_classifier_terms'

        belongs_to :category,  '::Yito::Model::Booking::BookingCategory', :child_key => [:category_code], :parent_key => [:code], :key => true
        belongs_to :classifier_term, '::Yito::Model::Classifier::ClassifierTerm', :child_key => [:classifier_term_id], :parent_key => [:id], :key => true

      end
    end
  end
end