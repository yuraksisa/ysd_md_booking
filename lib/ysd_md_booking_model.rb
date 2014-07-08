require 'data_mapper' unless defined?DataMapper
require 'dm-types'
require 'ysd_md_booking_charge'
require 'ysd_md_audit' unless defined?Audit::Auditor
require 'ysd_md_yito' unless defined?Yito::Model::Finder
require 'digest/md5' unless defined?Digest::MD5

module BookingDataSystem

  # ---------------------------------------- 
  # This represents an booking for a item
  #
  # Booking status
  #
  #  - pending_confirmation. The customer make the booking but he/she doesn't
  #    make a deposit
  #
  #  - confirmed. A deposit has been charged
  #
  #  - in_progress. The customer has received the item 
  #
  #  - done. The customer has returned the item
  #
  #  - cancelled. The booking has been canceled
  #
  # ----------------------------------------
  class Booking 
     include DataMapper::Resource
     include BookingNotifications
     include Audit::Auditor
     include BookingDataSystem::BookingGuests
     include BookingDataSystem::BookingDriver
     include BookingDataSystem::BookingPickupReturn
     include BookingDataSystem::BookingFlight
     extend Yito::Model::Finder
    
     storage_names[:default] = 'bookds_bookings' # stored in bookings table in default storage
     
     property :id, Serial, :field => 'id'
     
     property :creation_date, DateTime, :field => 'creation_date'  # The creation date
     property :created_by_manager, Boolean, :field => 'created_by_manager', :default => false
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
     
     property :total_paid, Decimal, :field => 'total_paid', :scale => 2, :precision => 10, :default => 0
     property :total_pending, Decimal, :field => 'total_pending', :scale => 2, :precision => 10, :default => 0

     property :pay_now, Boolean, :field => 'pay_now', :default => false
     property :payment, String, :field => 'payment', :length => 10
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
     property :customer_language, String, :field => 'customer_language', :length => 3

     property :comments, String, :field => 'comments', :length => 1024
     
     property :free_access_id, String, :field => 'free_access_id', :length => 32, :unique_index => :booking_free_access_id_index

     has n, :booking_extras, 'BookingExtra', :constraint => :destroy 
     
     property :status, Enum[:pending_confirmation, :confirmed,  
       :in_progress, :done, :cancelled], :field => 'status', :default => :pending_confirmation

     property :payment_status, Enum[:none, :deposit, :total], 
       :field => 'payment_status', :default => :none

     belongs_to :booking_item, 'Yito::Model::Booking::BookingItem', 
       :child_key => [:booking_item_reference], :parent_key => [:reference], 
       :required => false
     
     #
     # Get a booking by its free access id
     #
     # @parm [String] free access id
     # @return [Booking] 
     def self.get_by_free_access_id(free_id)
        first({:free_access_id => free_id})
     end 
     
     #
     # Saving a booking
     #
     def save
       result = true
       if new?
         transaction do 
           auto_create_online_charge!
           begin
             result = super
           rescue DataMapper::SaveFailureError => error
             p "Error saving booking #{error} #{self.inspect}"
             raise error 
           end
           reload
           unless created_by_manager
             if pay_now 
               notify_manager_pay_now
               notify_request_to_customer_pay_now
             else
               notify_manager
               notify_request_to_customer
             end
           end 
         end
       else
         result = super
       end
       return result
     end
     
     #
     # Before create hook (initilize fields)
     #
     before :create do |booking|
       booking.creation_date = Time.now if not booking.creation_date
       booking.total_pending = total_cost
       booking.free_access_id = 
         Digest::MD5.hexdigest("#{rand}#{customer_name}#{customer_surname}#{customer_email}#{item_id}#{rand}")
     end
      
     #
     # Get the deposit amount
     #
     def booking_deposit

       (total_cost * SystemConfiguration::Variable.get_value('booking.deposit', '0').to_i / 100).round

     end
     
     #
     # Get the charge item detail
     #
     def charge_item_detail
    
        "#{item_description} #{date_from.strftime('%d/%m/%Y')} - #{date_to.strftime('%d/%m/%Y')}" 

     end

     #
     # Creates an online charge 
     #
     # @param [String] payment to be created : deposit, total, pending
     # @param [String] payment method id
     #
     # @return [Charge] The created charge
     #
     def create_online_charge!(charge_payment, charge_payment_method_id)
       
       if total_pending > 0 and 
          charge_payment_method = Payments::PaymentMethod.get(charge_payment_method_id.to_sym) and
          not charge_payment_method.is_a?Payments::OfflinePaymentMethod 

         amount = case charge_payment.to_sym
                    when :deposit
                      (total_cost * SystemConfiguration::Variable.get_value('booking.deposit', '0').to_i / 100).round
                    when :total
                      total_cost
                    when :pending
                      total_pending
                  end

         charge = new_charge!(charge_payment_method_id, amount) if amount > 0
         save
         return charge
       end 

     end
     
     #
     # Confirms the booking
     #
     # A booking can only be confirmed if it's pending confirmation 
     # and contains a done charge
     #
     # @return [Booking]
     #
     def confirm
       if status == :pending_confirmation and
          not charges.select { |charge| charge.status == :done }.empty?
         self.status = :confirmed
         save
         notify_manager
         notify_customer
       else
         p "Could not confirm booking #{id} #{status}"
       end
       
       self
     end
     
     #
     # Confirm the booking without checking the charges
     #
     # @return [Booking]
     #
     def confirm!
       if status == :pending_confirmation 
         update(:status => :confirmed)
       end
       self
     end

     #
     # Deliver the item to the customer
     #
     # @return [Booking]
     #
     def pickup_item
       if status == :confirmed 
         update(:status => :in_progress)
       end
       self
     end

     alias_method :arrival, :pickup_item
     
     #
     # The item is returned from the customer
     #
     # @return [Booking]
     #
     def return_item 
       if status == :in_progress
         update(:status => :done)
       end
       self
     end

     alias_method :departure, :return_item
 
     #
     # Cancels a booking
     #
     # A booking can only be cancelled if it isn't already cancelled
     # 
     # @return [Booking]
     #
     def cancel
      
       unless status == :cancelled
         update(:status => :cancelled)
       end

       self
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
     # Exporting to json
     #
     def as_json(options={})
 
       relationships = options[:relationships] || {}
       relationships.store(:charges, {})
       relationships.store(:booking_extras, {})
       relationships.store(:booking_item, {})

       super(options.merge({:relationships => relationships}))
    
     end

     #
     # Get the reservations received grouped by month
     #
     def self.reservations_received
       
       function = nil
       format = nil

       case repository(:default).adapter.options.symbolize_keys[:adapter]
                    when 'mysql'
                      function ='DATE_FORMAT'
                      format = '%Y-%M'
                    else
                      function = 'TO_CHAR'
                      format = 'YYYY-MM'
                  end

       query = <<-QUERY
          SELECT #{function}(creation_date, '#{format}') as period, 
                 count(*) as occurrences
          FROM bookds_bookings
          GROUP BY period
          order by period
       QUERY

       reservations=repository(:default).adapter.select(query)

     end

     #
     # Get the reservations confirmed grouped by month
     #
     def self.reservations_confirmed

       function = nil
       format = nil

       case repository(:default).adapter.options.symbolize_keys[:adapter]
                    when 'mysql'
                      function ='DATE_FORMAT'
                      format = '%Y-%M'
                    else
                      function = 'TO_CHAR'
                      format = 'YYYY-MM'
                  end
       
       query = <<-QUERY
          SELECT #{function}(creation_date, '#{format}') as period, 
                 count(*) as occurrences
          FROM bookds_bookings
          WHERE status IN (2,3,4)
          GROUP BY period 
          order by period
       QUERY

       reservations=repository(:default).adapter.select(query)

     end

     private

     #
     # When a new booking is created, check if a new charge should be created
     # to process the booking payment
     #
     # @return [Payments::Charge]
     #
     def auto_create_online_charge!

       if (charges.empty? and booking_charges.empty?) and 
         payment_method and not payment_method.is_a?Payments::OfflinePaymentMethod

         case payment
           when 'deposit'
             self.booking_amount = (total_cost * SystemConfiguration::Variable.get_value('booking.deposit', '0').to_i / 100).round
           when 'total'
             self.booking_amount = total_cost
           else
             self.booking_amount = 0
         end
         new_charge!(payment_method_id, self.booking_amount) if self.booking_amount > 0

       end

     end
     
     #
     # Creates a new charge for the booking
     #
     # @param [String] payment_method_id
     # @param [Number] amount
     #
     # @return [Payments::Charge] The created charge
     #
     def new_charge!(charge_payment_method_id, charge_amount)
       charge = Payments::Charge.create({:date => Time.now,
           :amount => charge_amount, 
           :payment_method_id => charge_payment_method_id,
           :currency => SystemConfiguration::Variable.get_value('payments.default_currency', 'EUR') }) 
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
