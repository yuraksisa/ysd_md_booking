require 'data_mapper' unless defined?DataMapper
require 'ysd_md_booking_charge'

module BookingDataSystem

  # ---------------------------------------- 
  # This represents an booking for a item
  # ----------------------------------------
  class Booking 
     include DataMapper::Resource
     include BookingNotifications
    
     storage_names[:default] = 'bookds_bookings' # stored in bookings table in default storage
     
     property :id, Serial, :field => 'id'
     
     property :creation_date, DateTime, :field => 'creation_date'  # The creation date
     property :source, String, :field => 'source', :length => 50   # Where does the booking come from
     
     property :date_from, DateTime, :field => 'date_from', :required => true
     property :time_from, String, :field => 'time_from', :required => false, :length => 5
     property :date_to, DateTime, :field => 'date_to', :required => true 
     property :time_to, String, :field => 'time_to', :required => false, :length => 5
     
     property :item_id, String, :field => 'item_id', :required => true, :length => 20
     property :item_description, String, :field => 'item_description', :required => false, :length => 256
     property :optional, String, :field => 'optional', :length => 40
     
     property :item_cost, Decimal, :field => 'item_cost', :scale => 2, :precision => 10
     property :extras_cost, Decimal, :field => 'extras_cost', :scale => 2, :precision => 10
     property :total_cost, Decimal, :field => 'total_cost', :scale => 2, :precision => 10
     
     property :booking_amount, Decimal, :field => 'booking_amount', :scale => 2, :precision => 10
     property :payment_method_id, String, :field => 'payment_method_id', :length => 30
     has n, :booking_charges, 'BookingCharge', :child_key => [:booking_id], :parent_key => [:id]
     has n, :charges, 'Payments::Charge', :through => :booking_charges
     
     property :quantity, Integer, :field => 'quantity'
     property :date_to_price_calculation, DateTime, :field => 'date_to_price_calculation'
     property :days, Integer, :field => 'days'
     
     property :customer_name, String, :field => 'customer_name', :required => true, :length => 40
     property :customer_surname, String, :field => 'customer_surname', :required => true, :length => 40
     property :customer_email, String, :field => 'customer_email', :required => true, :length => 40
     property :customer_phone, String, :field => 'customer_phone', :required => true, :length => 15 
     property :customer_mobile_phone, String, :field => 'customer_mobile_phone', :length => 15
     
     property :comments, String, :field => 'comments', :length => 1024
     
     has n, :booking_extras, 'BookingExtra' 
     
     def save
       transaction do 
         check_charge! if new?
         super
       end
     end

     before :create do |booking|
       booking.creation_date = Time.now if not booking.creation_date
     end
     
     after :create do 
       create_new_booking_business_event!
     end
     
     #
     # Gets the payment method instance
     # 
     def payment_method
       if payment_method_id.nil?
         return nil 
       else
         @payment_method ||= Payments::PaymentMethod.get(payment_method_id.to_sym)
       end
     end
     
     #
     # Creates a deposit charge 
     #
     def create_deposit_charge!
       if payment_method and not payment_method.is_a?Payments::OfflinePaymentMethod
         charge = new_deposit_charge!
         save
         return charge
       end 
     end

     private

     #
     # It checks if a deposit charge should be created
     #
     def check_charge!

       if charges.empty? and payment_method and not payment_method.is_a?Payments::OfflinePaymentMethod
         new_deposit_charge!
       end

     end
     
     #
     # Creates a deposit charge
     #
     # @return [Payments::Charge] The created charge
     #
     def new_deposit_charge!
       charge = Payments::Charge.create({:date => Time.now,
           :amount => booking_amount, 
           :payment_method_id => payment_method_id }) 
       self.charges << charge
       return charge
     end
     
     #
     # Creates a new business event to notify a booking has been created
     #
     def create_new_booking_business_event!
       BusinessEvents::BusinessEvent.fire_event(:new_booking, 
         {:booking_id => id})
     end

  end

   

end