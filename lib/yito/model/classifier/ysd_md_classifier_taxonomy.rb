require 'data_mapper' unless defined?DataMapper

module Yito
  module Model
    module Classifier
      class ClassifierTaxonomy
        include DataMapper::Resource

        storage_names[:default] = 'classifierds_taxonomies'

        property :id, Serial
        property :name, String, length: 50
        property :description, Text
        property :weight, Integer, default: 0
        property :tag_group, String, length: 50 # It allows to define a classifier taxonomy to be used to classify some kind of data
        property :color, String, length: 50
        
        has n, :classifier_terms, 'ClassifierTerm', :child_key => [:classifier_taxonomy_id], :parent_key => [:id], :constraint => :destroy
      end
    end
  end
end