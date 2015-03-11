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
     belongs_to :booking_line, 'BookingLine', :child_key => [:booking_line_id]
     belongs_to :booking_item, 'Yito::Model::Booking::BookingItem', 
       :child_key => [:booking_item_reference], :parent_key => [:reference], :required => false

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