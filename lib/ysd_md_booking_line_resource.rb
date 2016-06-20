require 'data_mapper' unless defined?DataMapper

module BookingDataSystem
  # 
  # Represent a booking line with a item and a quantity
  #
  class BookingLineResource
     include DataMapper::Resource
     include BookingDataSystem::BookingHeightWeight     
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

  end
end