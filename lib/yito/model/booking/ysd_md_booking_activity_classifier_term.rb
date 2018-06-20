module Yito
  module Model
    module Booking
      class ActivityClassifierTerm
        include DataMapper::Resource

        storage_names[:default] = 'bookds_activity_classifier_terms'

        belongs_to :activity,  '::Yito::Model::Booking::Activity', :child_key => [:activity_id], :parent_key => [:id], :key => true
        belongs_to :classifier_term, '::Yito::Model::Classifier::ClassifierTerm', :child_key => [:classifier_term_id], :parent_key => [:id], :key => true

      end
    end
  end
end