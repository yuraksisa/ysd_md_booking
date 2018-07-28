require 'data_mapper' unless defined?DataMapper

module BookingDataSystem
  # 
  # Represent a booking line with a item and a quantity
  #
  class BookingLineResource
     include DataMapper::Resource
     storage_names[:default] = 'bookds_bookings_lines_resources' 
     property :id, Serial

     property :resource_user_name, String, :length => 80
     property :resource_user_surname, String, :length => 80
     property :resource_user_document_id, String, :length => 50
     property :resource_user_phone, String, :length => 15
     property :resource_user_email, String, :length => 40

     property :resource_user_2_name, String, :length => 80
     property :resource_user_2_surname, String, :length => 80
     property :resource_user_2_document_id, String, :length => 50
     property :resource_user_2_phone, String, :length => 15
     property :resource_user_2_email, String, :length => 40

     property :pax, Integer, :default => 1 # Number of people responsible of the resource

     belongs_to :booking_line, 'BookingLine', :child_key => [:booking_line_id]

     property :booking_item_category, String, :length => 20
     property :booking_item_reference, String, :length => 50
     property :booking_item_stock_model, String, :length => 80
     property :booking_item_stock_plate, String, :length => 80
     property :booking_item_characteristic_1, String, :length => 80
     property :booking_item_characteristic_2, String, :length => 80
     property :booking_item_characteristic_3, String, :length => 80
     property :booking_item_characteristic_4, String, :length => 80

     # Booking extensions
     
     include BookingDataSystem::BookingHeightWeight
     include Yito::Model::Booking::BookingPickupReturnUnits

     def booking_item
       if !booking_item_reference.nil? and !booking_item_reference.empty?
         item = ::Yito::Model::Booking::BookingItem.get(booking_item_reference)
       end
     end

     def item_id
       booking_line.item_id
     end

     def item_description
       booking_line.item_description
     end

     #
     # Exporting to json
     #
     def as_json(options={})

       if options.has_key?(:only)
         super(options)
       else
         relationships = options[:relationships] || {}
         methods = options[:methods] || []
         methods << :item_id
         methods << :item_description
         super(options.merge({:relationships => relationships, :methods => methods}))
       end

     end

     # --------------------------- Resource assignation management -----------------------------------------

     #
     # Clear the assigned resource
     #
     def clear_assignation
       old_resource = self.booking_item_reference
       self.booking_item_category = nil
       self.booking_item_reference = nil
       self.booking_item_stock_model = nil
       self.booking_item_stock_plate = nil
       self.booking_item_characteristic_1 = nil
       self.booking_item_characteristic_2 = nil
       self.booking_item_characteristic_3 = nil
       self.booking_item_characteristic_4 = nil
       self.save
       ::Yito::Model::Newsfeed::Newsfeed.create(category: 'booking',
                                                action: 'clear_booking_resource',
                                                identifier: self.booking_line.booking.id.to_s,
                                                description: BookingDataSystem.r18n.t.booking_news_feed.clear_booking_resource(old_resource,
                                                                                                                                self.booking_line.id,
                                                                                                                                self.booking_line.item_id),
                                                attributes_updated: {category: nil,
                                                                     reference: nil,
                                                                     stock_model: nil,
                                                                     stock_plate: nil,
                                                                     characteristic_1: nil,
                                                                     characteristic_2: nil,
                                                                     characteristic_3: nil,
                                                                     characteristic_4: nil}.to_json)
     end

     #
     # Assign a resource
     #
     def assign_resource(new_booking_item_reference)

       if new_booking_item_reference != self.booking_item_reference
         if booking_item = ::Yito::Model::Booking::BookingItem.get(new_booking_item_reference)
           assignation_allow_different_category = SystemConfiguration::Variable.get_value('booking.assignation.allow_different_category', 'true').to_bool
           if assignation_allow_different_category or
              (!assignation_allow_different_category and booking_item.category_code == item_id)
             self.booking_item_category = booking_item.category.code if booking_item.category
             self.booking_item_reference = booking_item.reference
             self.booking_item_stock_model = booking_item.stock_model
             self.booking_item_stock_plate = booking_item.stock_plate
             self.booking_item_characteristic_1 = booking_item.characteristic_1
             self.booking_item_characteristic_2 = booking_item.characteristic_2
             self.booking_item_characteristic_3 = booking_item.characteristic_3
             self.booking_item_characteristic_4 = booking_item.characteristic_4
             self.save
             ::Yito::Model::Newsfeed::Newsfeed.create(category: 'booking',
                                                      action: 'assign_booking_resource',
                                                      identifier: self.booking_line.booking.id.to_s,
                                                      description: BookingDataSystem.r18n.t.booking_news_feed.assign_booking_resource(self.booking_item_reference,
                                                                                                                                      self.booking_line.id,
                                                                                                                                      self.booking_line.item_id),
                                                      attributes_updated: {category: self.booking_item_category,
                                                                           reference: self.booking_item_reference,
                                                                           stock_model: self.booking_item_stock_model,
                                                                           stock_plate: self.booking_item_stock_plate,
                                                                           characteristic_1: self.booking_item_characteristic_1,
                                                                           characteristic_2: self.booking_item_characteristic_2,
                                                                           characteristic_3: self.booking_item_characteristic_3,
                                                                           characteristic_4: self.booking_item_characteristic_4}.to_json)

           end
         end
       end

     end

  end
end