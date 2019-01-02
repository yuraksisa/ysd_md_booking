require 'data_mapper' unless defined?DataMapper::Resource
require 'ysd_plugin_sales_channels/model/ysd_md_sales_channels' unless defined? ::Yito::Model::SalesChannel::SalesChannel
require 'ysd_md_booking_category' unless defined? ::Yito::Model::Booking::BookingCategory

module Yito
  module Model
    module Booking
      class BookingCategoriesSalesChannel
        include DataMapper::Resource
        extend  Plugins::ApplicableModelAspect  # Extends the entity to allow apply aspects
        
        storage_names[:default] = 'bookds_categories_channels' 

        property :id, Serial
        property :name, String, :length => 80
        property :short_description, String, :length => 80
        property :title, String, length: 100
        property :subtitle, Text
        property :description, Text

        property :price_definition_own_season_definition, Boolean, default: false
        property :price_definition_own_factor_definition, Boolean, default: false
        
        property :category_supplement_1_cost, Decimal, scale: 2, precision: 10, default: 0
        property :category_supplement_2_cost, Decimal, scale: 2, precision: 10, default: 0
        property :category_supplement_3_cost, Decimal, scale: 2, precision: 10, default: 0
        
        belongs_to :price_definition, 'Yito::Model::Rates::PriceDefinition', :required => false

        belongs_to :booking_category, 'Yito::Model::Booking::BookingCategory', child_key: [:booking_category_code]
        belongs_to :sales_channel, 'Yito::Model::SalesChannel::SalesChannel', child_key: [:sales_channel_id]

        # -------------------------- Hooks -----------------------------------------------------
        
        after :destroy do
          
          # Destroy the price definition season definition
          if price_definition_own_season_definition
            self.price_definition.season_definition.destroy if self.price_definition and self.price_definition.season_definition  
          end
          
          # Destroy the price definition factor definition
          if price_definition_own_factor_definition
            self.price_definition.factor_definition.destroy if self.price_definition and self.price_definition.factor_definition
          end
          
          # Delete the rates
          self.price_definition.destroy if price_definition

        end
        
      end
    end
  end
end