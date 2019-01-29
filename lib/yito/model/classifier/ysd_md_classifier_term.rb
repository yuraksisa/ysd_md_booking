require 'data_mapper' unless defined?DataMapper

module Yito
  module Model
    module Classifier
      class ClassifierTerm
        include DataMapper::Resource
        extend Plugins::ApplicableModelAspect         # Extends the term to allow apply aspects

        storage_names[:default] = 'classifierds_terms'

        property :id, Serial
        property :name, String, length: 50
        property :description, Text
        property :weight, Integer, default: 0
        
        belongs_to :classifier_taxonomy, 'ClassifierTaxonomy', :child_key => [:classifier_taxonomy_id], :parent_key => [:id]
        belongs_to :parent, 'ClassifierTerm', :child_key => [:parent_id], :parent_key => [:id], :required => false
      end
    end
  end
end