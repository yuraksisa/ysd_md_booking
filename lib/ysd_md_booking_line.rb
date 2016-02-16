require 'data_mapper' unless defined?DataMapper

module BookingDataSystem
  # 
  # Represent a booking line with a item and a quantity
  #
  class BookingLine
     include DataMapper::Resource
     storage_names[:default] = 'bookds_bookings_lines' 
 
     property :id, Serial
     property :item_id, String, :length => 20, :required => true
     property :item_description, String, :length => 256
     property :optional, String, :length => 40
     property :item_unit_cost_base, Decimal, :precision => 10, :scale => 2
     property :item_unit_cost, Decimal, :precision => 10, :scale => 2
     property :item_cost, Decimal, :precision => 10, :scale => 2
     property :quantity, Integer
     property :product_deposit_unit_cost, Decimal, :precision => 10, :scale => 2, :default => 0
     property :product_deposit_cost, Decimal, :precision => 10, :scale => 2, :default => 0
     belongs_to :booking, 'Booking', :child_key => [:booking_id]
     has n, :booking_line_resources, 'BookingLineResource', :constraint => :destroy 

     #
     # Exporting to json
     #
     def as_json(options={})

       if options.has_key?(:only)
         super(options)
       else
         relationships = options[:relationships] || {}
         relationships.store(:booking_line_resources, {})
         super(options.merge({:relationships => relationships}))
       end

     end

  end
end