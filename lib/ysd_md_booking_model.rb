require 'data_mapper' unless defined?DataMapper
require 'dm-types'
require 'date'
require 'ysd_md_booking_charge'
require 'ysd_md_audit' unless defined?Audit::Auditor
require 'ysd_md_yito' unless defined?Yito::Model::Finder
require 'digest/md5' unless defined?Digest::MD5
require 'ysd_md_yito' unless defined?Yito::Model::UserAgentData

module BookingDataSystem

  # ---------------------------------------- 
  # This represents an booking for a item
  #
  # Booking status
  #
  #  - pending_confirmation. The customer make the reservation but he/she doesn't
  #    make a deposit
  #
  #  - confirmed. A deposit has been charged
  #
  #  - in_progress. The customer has received the item 
  #
  #  - done. The customer has returned the item
  #
  #  - cancelled. The reservation has been canceled
  #
  # Expired
  #
  #   It's the number of hours between the date when the reservation was received 
  #   and now (the current date/time)
  #
  #   If the number of hours exceed the configuration parameter, booking.item_hold_time, the
  #   reservation is expired and the user won't be able to pay for it, except if the manager
  #   force the payment (force_allow_payment)
  #
  # Payment cadence
  #
  #   It's the number of hours between the date when the reservation was received
  #   and the reservation start date/time.
  #
  #   If the number of hours exceed the configuration parameter, booking.payment_cadence, the
  #   user won't be able to pay for it, except if the manager force the payment (force_allow_payment)
  #
  # ----------------------------------------
  class Booking 
     include DataMapper::Resource
     extend BookingNotificationTemplates
     include BookingNotifications
     include Audit::Auditor
     include BookingDataSystem::BookingGuests
     include BookingDataSystem::BookingDriver
     include BookingDataSystem::BookingPickupReturn
     include BookingDataSystem::BookingFlight
     extend Yito::Model::Booking::Queries
     extend Yito::Model::Finder
     include Yito::Model::UserAgentData
    
     storage_names[:default] = 'bookds_bookings' # stored in bookings table in default storage
     
     property :id, Serial, :field => 'id'
     
     property :creation_date, DateTime, :field => 'creation_date'  # The creation date
     property :created_by_manager, Boolean, :field => 'created_by_manager', :default => false
     property :source, String, :field => 'source', :length => 50   # Where does the booking come from
     
     property :date_from, DateTime, :field => 'date_from', :required => true
     property :time_from, String, :field => 'time_from', :required => false, :length => 5
     property :date_to, DateTime, :field => 'date_to', :required => true 
     property :time_to, String, :field => 'time_to', :required => false, :length => 5
          
     property :item_cost, Decimal, :field => 'item_cost', :scale => 2, :precision => 10
     property :extras_cost, Decimal, :field => 'extras_cost', :scale => 2, :precision => 10
     property :time_from_cost, Decimal, :scale => 2, :precision => 10
     property :time_to_cost, Decimal, :scale => 2, :precision => 10
     property :product_deposit_cost, Decimal, :scale => 2, :precision => 10, :default => 0
     property :total_cost, Decimal, :field => 'total_cost', :scale => 2, :precision => 10
     
     property :total_paid, Decimal, :field => 'total_paid', :scale => 2, :precision => 10, :default => 0
     property :total_pending, Decimal, :field => 'total_pending', :scale => 2, :precision => 10, :default => 0

     property :pay_now, Boolean, :field => 'pay_now', :default => false
     property :force_allow_payment, Boolean, :field => 'force_allow_payment', :default => false
     property :payment, String, :field => 'payment', :length => 10
     property :booking_amount, Decimal, :field => 'booking_amount', :scale => 2, :precision => 10
     property :payment_method_id, String, :field => 'payment_method_id', :length => 30
     has n, :booking_charges, 'BookingCharge', :child_key => [:booking_id], :parent_key => [:id]
     has n, :charges, 'Payments::Charge', :through => :booking_charges
     
     property :date_to_price_calculation, DateTime, :field => 'date_to_price_calculation'
     property :days, Integer, :field => 'days'
     
     property :customer_name, String, :field => 'customer_name', :required => true, :length => 40
     property :customer_surname, String, :field => 'customer_surname', :required => true, :length => 40
     property :customer_email, String, :field => 'customer_email', :required => true, :length => 40
     property :customer_phone, String, :field => 'customer_phone', :required => true, :length => 15 
     property :customer_mobile_phone, String, :field => 'customer_mobile_phone', :length => 15
     property :customer_language, String, :field => 'customer_language', :length => 3

     property :comments, String, :field => 'comments', :length => 1024
     property :notes, Text
     
     property :free_access_id, String, :field => 'free_access_id', :length => 32, :unique_index => :booking_free_access_id_index

     has n, :booking_extras, 'BookingExtra', :constraint => :destroy
     has n, :booking_lines, 'BookingLine', :constraint => :destroy
     has n, :booking_line_resources, 'BookingLineResource', :through => :booking_lines
     
     property :status, Enum[:pending_confirmation, :confirmed,  
       :in_progress, :done, :cancelled], :field => 'status', :default => :pending_confirmation

     property :payment_status, Enum[:none, :deposit, :total, :refunded], 
       :field => 'payment_status', :default => :none

     property :planning_color, String, :length => 9
     belongs_to :main_booking, 'Booking', :child_key => [:main_booking_id], :parent_key => [:id],
       :required => false
     property :promotion_code, String, :length => 256
     
     belongs_to :destination_address, 'LocationDataSystem::Address', :required => false # The driver address
     property :comercial_agent, String, :length => 256

     property :pickup_time, String, :length => 5
     property :pickup_agent, String, :length => 256
     property :return_time, String, :length => 5
     property :return_agent, String, :length => 256

     # --------------------------  CLASS METHODS -----------------------------------------------------------

     #
     # Parses date and time (from)
     #
     def self.parse_date_time_from(date, time=nil)

       parsing_time = if time.nil? or time.empty?
                        "10:00"
                      else 
                        time
                      end 

       parse_date_time(date, parsing_time)
     end

     #
     # Parses date and time (to)
     #
     def self.parse_date_time_to(date, time=nil)

       @@product_family ||= ::Yito::Model::Booking::ProductFamily.get(SystemConfiguration::Variable.get_value('booking.item_family'))

       parsing_time = if time.nil? or time.empty?
                        @@product_family and @@product_family.cycle_of_24_hours ? "10:00" : "20:00"
                      else 
                        time
                      end 

       parse_date_time(date, parsing_time)
     end
     
     #
     # Parses date and time
     #
     def self.parse_date_time(date, time)

       begin
         date_str = "#{date.strftime('%Y-%m-%d')}T#{time}:00#{date.strftime("%:z")}"
         result = DateTime.strptime(date_str,'%Y-%m-%dT%H:%M:%S%:z')
       rescue
         p "Invalid date #{date} #{time}"
         result = date
       end

       return date

     end

     # --------------------------  INSTANCE METHODS -------------------------------------------------------


     #
     # Get a booking by its free access id
     #
     # @parm [String] free access id
     # @return [Booking] 
     def self.get_by_free_access_id(free_id)
        first({:free_access_id => free_id})
     end 
     
     def category
       booking_lines and booking_lines.size > 0 ? ::Yito::Model::Booking::BookingCategory.get(booking_lines[0].item_id) : nil
     end

     #
     # Saving a booking
     #
     def save
       result = true
       if new?
         transaction do 
           begin
             result = super
           rescue DataMapper::SaveFailureError => error
             p "Error saving booking #{error} #{self.inspect} #{self.booking_extras.inspect} #{self.errors.inspect}"
             raise error 
           end
           reload
           #unless created_by_manager
           if pay_now 
             notify_manager_pay_now
             notify_request_to_customer_pay_now
           else
             notify_manager
             notify_request_to_customer
           end
           #end 
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
         Digest::MD5.hexdigest("#{rand}#{customer_name}#{customer_surname}#{customer_email}#{rand}")
     end
     
     #
     # Before save hook (clear leading and trailing whitespaces)
     #
     before :save do |booking|
       booking.customer_name.strip! unless booking.customer_name.nil?
       booking.customer_surname.strip! unless booking.customer_surname.nil?
       booking.customer_phone.strip! unless booking.customer_phone.nil?
     end
     
     #
     # Check if the reservation has expired
     #
     def expired?
         conf_item_hold_time = SystemConfiguration::Variable.get_value('booking.item_hold_time', '0').to_i
         hold_time_diff_in_hours = (DateTime.now.to_time - self.creation_date.to_time) / 3600
         expired = (hold_time_diff_in_hours > conf_item_hold_time)
         expired && !force_allow_payment
     end

     #
     # Check the payment cadence is allowed
     # 
     def payment_cadence_allowed?
         begin
           config_payment_cadence = SystemConfiguration::Variable.get_value('booking.payment_cadence').to_i
           _date_from_str = "#{self.date_from.strftime('%Y-%m-%d')}T#{self.time_from}:00#{self.date_from.strftime("%:z")}"
           _date_from = DateTime.strptime(_date_from_str,'%Y-%m-%dT%H:%M:%S%:z')
           diff_in_hours = (_date_from.to_time - self.creation_date.to_time) / 3600
           allowed = diff_in_hours > 0 && (diff_in_hours >= config_payment_cadence)
           allowed || force_allow_payment
         rescue => error
           p "Error #{id} #{date_from} #{time_from} #{date_to} #{time_to} #{driver_date_of_birth} #{driver_driving_license_date}"
           return false
         end
     end

     #
     # Check if the customer can pay for the reservation
     #
     def can_pay?

       conf_payment_enabled = SystemConfiguration::Variable.get_value('booking.payment', 'false').to_bool
       conf_allow_total_payment = SystemConfiguration::Variable.get_value('booking.allow_total_payment','false').to_bool

       can_pay = (total_pending > 0 && status != :cancelled && (conf_payment_enabled || force_allow_payment)) 

       if can_pay
         if self.total_paid > 0 # It's not the first payment
           can_pay = (can_pay && conf_allow_total_payment) 
         else  # It's the first payment (check expiration)
           can_pay = (can_pay && !expired? && (payment_cadence_allowed? || force_allow_payment)) || (total_pending > 0 && status == :confirmed)
         end
       end            

       return can_pay

     end

     #
     # Check if the reservation is within the cadence period
     #
     def self.payment_cadence?(date_from)

         conf_payment_cadence = SystemConfiguration::Variable.get_value('booking.payment_cadence', '0').to_i

         cadence_from = DateTime.parse("#{date_from.strftime('%Y-%m-%d')}T00:00:00")
         cadence_payment = (cadence_from.to_time - DateTime.now.to_time) / 3600
         cadence_payment > conf_payment_cadence

     end

     alias_method :is_expired, :expired?
     alias_method :can_pay, :can_pay?

     #
     # Get the deposit amount
     #
     def booking_deposit

       (total_cost * SystemConfiguration::Variable.get_value('booking.deposit', '0').to_i / 100).round

     end
     
     #
     # Get a list of the other people involved in the contract (extracted from resources)
     #
     def contract_other_people
       result = []
       booking_line_resources.each do |resource|
         result << { :name => resource.resource_user_name,
                     :surname => resource.resource_user_surname,
                     :document_id => resource.resource_user_document_id,
                     :phone => resource.resource_user_phone,
                     :email => resource.resource_user_email } if resource.resource_user_name != customer_name and 
                                                                 resource.resource_user_surname != customer_surname
         if resource.pax == 2
           result << { :name => resource.resource_user_2_name,
                       :surname => resource.resource_user_2_surname,
                       :document_id => resource.resource_user_2_document_id,
                       :phone => resource.resource_user_2_phone,
                       :email => resource.resource_user_2_email } if resource.resource_user_2_name != customer_name and 
                                                                     resource.resource_user_2_surname != customer_surname
      
         end
       end

       return result
     end
     
     #
     # Get the charge item detail
     #
     def charge_item_detail
    
        "#{date_from.strftime('%d/%m/%Y')} - #{date_to.strftime('%d/%m/%Y')}" 

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
         notify_manager_confirmation 
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
         transaction do 
           if total_paid > 0
             update(:status => :cancelled, :payment_status => :refunded, :total_paid => 0, :total_pending => total_cost)
           else 
             update(:status => :cancelled)
           end
           charges.each do |charge|
             charge.refund
           end
         end
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

       if options.has_key?(:only)
         super(options)
       else
         relationships = options[:relationships] || {}
         relationships.store(:charges, {})
         relationships.store(:booking_extras, {})
         relationships.store(:booking_lines, {})
         relationships.store(:booking_line_resources, {})
         relationships.store(:booking_item, {})
         relationships.store(:driver_address, {})
         relationships.store(:destination_address, {})
         methods = options[:methods] || []
         methods << :is_expired
         methods << :can_pay
         super(options.merge({:relationships => relationships, :methods => methods}))
       end

     end

     def item_unit_cost
       item_cost / days
     end
     
     def extras_summary
       extras_s = booking_extras.inject({}) do |result, extra|
         result.store(extra.extra_id, {quantity: extra.quantity, cost: extra.extra_cost})
         result
       end 
       extras_s.store('entrega_fuera_horas', {quantity: 1, cost: time_from_cost})
       extras_s.store('recogida_fuera_horas', {quantity: 1, cost: time_to_cost})
       extras_s.store('lugar_entrega', {quantity: 1, cost: pickup_place_cost})
       extras_s.store('lugar_recogida', {quantity: 1, cost: return_place_cost})
       extras_s.store('fuera_horas', {quantity: 1, cost: time_from_cost + time_to_cost})
       extras_s.store('lugar', {quantity: 1, cost: pickup_place_cost + return_place_cost})

       return extras_s
     end

     private
     
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
