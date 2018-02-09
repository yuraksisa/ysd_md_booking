module Yito
  module Model
    module Booking
      module SalesManagement

        def self.included(model)

          if model.respond_to?(:has)
            model.has Infinity, :booking_categories_sales_channels, 'BookingCategoriesSalesChannel', child_key: [:booking_category_code],
                parent_key: [:code], constraint: :destroy
            model.has Infinity, :sales_channels, 'Yito::Model::SalesChannel::SalesChannel', through: :booking_categories_sales_channels
          end

          #
          # Check if the booking category is operative in sales channel
          #
          def operative_in_sales_channel?(sales_channel)

            sales_channels.select { |s_c| s_c.id == sales_channel.id }.size > 0

          end

          # Set up the sales channels
          #
          # == Parameters:
          # sales_channels::
          #   Array of ids with the sales channels
          #
          def setup_sales_channels(new_sales_channels_ids)
            
            transaction do

              # Remove the channels that no longer are defined for the booking category
              channels_to_remove = self.booking_categories_sales_channels.select { |b_c_s_c| !(new_sales_channels_ids.include?(b_c_s_c.sales_channel.id)) }
              p "Channels to remove: #{channels_to_remove.inspect}"
              channels_to_remove.each do |booking_category_sales_channel|
                booking_category_sales_channel.destroy
                # TODO : When deleting a channel make sure it deletes price definition - seasons - factors
              end

              # Create the new channels
              own_season_definition = SystemConfiguration::Variable.get_value('booking.new_season_definition_instance_for_category','false').to_bool
              own_factor_definition = SystemConfiguration::Variable.get_value('booking.new_factor_definition_instance_for_category','false').to_bool
              
              channels_to_add = new_sales_channels_ids.select { |item| !self.sales_channels.any? {|sales_channel| sales_channel.id == item} }
              p "Channels to add: #{channels_to_add.inspect}"
              channels_to_add.each do |sales_channel_id|
                sales_channel = ::Yito::Model::SalesChannel::SalesChannel.get(sales_channel_id)
                booking_category_sales_channel = ::Yito::Model::Booking::BookingCategoriesSalesChannel.new
                booking_category_sales_channel.booking_category = self
                booking_category_sales_channel.sales_channel = sales_channel
                booking_category_sales_channel.price_definition_own_season_definition = own_season_definition
                booking_category_sales_channel.price_definition_own_factor_definition = own_factor_definition
                if booking_item_family = ::Yito::Model::Booking::ProductFamily.get(SystemConfiguration::Variable.get_value('booking.item_family'))
                  price_definition = build_product_price_definition(sales_channel, own_season_definition, own_factor_definition)
                  price_definition.save
                  booking_category_sales_channel.price_definition = price_definition
                end
                booking_category_sales_channel.save
              end
              
            end
            
          end
          
          protected

          def build_product_price_definition(sales_channel, new_season_definition, new_factor_definition)

            if booking_item_family = ::Yito::Model::Booking::ProductFamily.get(SystemConfiguration::Variable.get_value('booking.item_family'))

              season_definition = nil
              factor_definition = nil

              # Season
              if booking_item_family.product_price_definition_type == :season
                if self.price_definition and self.price_definition.season_definition
                  if new_season_definition
                    # build a new season definition from the booking category
                    season_definition = self.price_definition.season_definition.make_copy
                    season_definition.name = "#{season_definition.name}_sc_#{sales_channel.id}"
                    season_definition.description = "#{season_definition.description} Channel: #{sales_channel.id}"
                    season_definition.save
                  else
                    season_definition = self.price_definition.season_definition
                  end
                end
              end
              
              # Factor
              if use_factors = SystemConfiguration::Variable.get_value('booking.use_factors_in_rates', 'false').to_bool
                if self.price_definition and self.price_definition.factor_definition
                  if new_factor_definition
                    # Build a new factor from the booking category
                    factor_definition = self.price_definition.factor_definition.make_copy
                    factor_definition.name = "#{factor_definition.name}_sc_#{sales_channel.id}"
                    factor_definition.description = "#{factor_definition.description} Channel: #{sales_channel.id}"
                    factor_definition.save
                  else
                    factor_definition = self.price_definition.factor_definition
                  end
                end
              end  
              
              price_definition = Yito::Model::Rates::PriceDefinition.new(
                name: "#{self.price_definition.name}_sc_#{sales_channel.id}",
                description: "#{self.price_definition.description} Channel: #{sales_channel.id}",
                type: self.price_definition.type,
                units_management: self.price_definition.units_management,
                units_management_value: self.price_definition.units_management_value,
                season_definition: season_definition,
                factor_definition: factor_definition)

            end  
          end
            
            
        end

      end
    end
  end
end