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
     
     storage_names[:default] = 'bookds_bookings' # stored in bookings table in default storage
     
     property :id, Serial, :field => 'id'
     
     property :creation_date, DateTime, :field => 'creation_date'  # The creation date
     property :created_by_manager, Boolean, :field => 'created_by_manager', :default => false
     property :source, String, :field => 'source', :length => 50   # Where does the booking come from
     
     property :date_from, DateTime, :field => 'date_from', :required => true
     property :time_from, String, :field => 'time_from', :required => false, :length => 5
     property :date_to, DateTime, :field => 'date_to', :required => true 
     property :time_to, String, :field => 'time_to', :required => false, :length => 5
          
     property :item_cost, Decimal, :field => 'item_cost', :scale => 2, :precision => 10, :default => 0
     property :extras_cost, Decimal, :field => 'extras_cost', :scale => 2, :precision => 10, :default => 0
     property :time_from_cost, Decimal, :scale => 2, :precision => 10, :default => 0
     property :time_to_cost, Decimal, :scale => 2, :precision => 10, :default => 0
     property :total_cost, Decimal, :field => 'total_cost', :scale => 2, :precision => 10, :default => 0

     property :product_deposit_cost, Decimal, :scale => 2, :precision => 10, :default => 0
     property :total_deposit, Decimal, :scale => 2, :precision => 10, :default => 0

     # quantity to pay in deposit (in order to confirm the reservation)
     property :booking_amount, Decimal, :field => 'booking_amount', :scale => 2, :precision => 10, :default => 0

     property :total_cost_includes_deposit, Boolean, default: false
     property :booking_amount_includes_deposit, Boolean, default: false

     property :total_paid, Decimal, :field => 'total_paid', :scale => 2, :precision => 10, :default => 0
     property :total_pending, Decimal, :field => 'total_pending', :scale => 2, :precision => 10, :default => 0

     property :pay_now, Boolean, :field => 'pay_now', :default => false
     property :force_allow_payment, Boolean, :field => 'force_allow_payment', :default => false
     property :payment, String, :field => 'payment', :length => 10
     property :payment_method_id, String, :field => 'payment_method_id', :length => 30
     has n, :booking_charges, 'BookingCharge', :child_key => [:booking_id], :parent_key => [:id]
     has n, :charges, 'Payments::Charge', :through => :booking_charges
     
     property :date_to_price_calculation, DateTime, :field => 'date_to_price_calculation'
     property :days, Integer, :field => 'days'
     
     property :customer_name, String, :field => 'customer_name', :required => true, :length => 40
     property :customer_surname, String, :field => 'customer_surname', :required => true, :length => 40
     property :customer_document_id, String, :length => 50
     property :customer_email, String, :field => 'customer_email', :length => 40
     property :customer_phone, String, :field => 'customer_phone', :length => 15
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

     property :planning_color, String, :length => 9, default: '#66ff66'
     belongs_to :main_booking, 'Booking', :child_key => [:main_booking_id], :parent_key => [:id],
       :required => false
     property :promotion_code, String, :length => 256

     property :destination_accommodation, Text
     belongs_to :destination_address, 'LocationDataSystem::Address', :required => false # The destination address
     property :comercial_agent, String, :length => 256

     property :pickup_time, String, :length => 5
     property :pickup_agent, String, :length => 256
     property :return_time, String, :length => 5
     property :return_agent, String, :length => 256

     belongs_to :rental_location, 'Yito::Model::Booking::RentalLocation', required: false
     property :sales_channel_code, String, length: 50

     # Booking extensions
     
     include BookingNotifications
     include Audit::Auditor
     include BookingDataSystem::BookingGuests
     include BookingDataSystem::BookingDriver
     include BookingDataSystem::BookingPickupReturn
     include BookingDataSystem::BookingFlight
     include Yito::Model::UserAgentData     
     include Yito::Model::Booking::BookingExternalInvoice
     include BookingDataSystem::BookingFuel
     include BookingDataSystem::BookingCrew
     include Yito::Model::Booking::SupplementsCalculation
     include Yito::Model::Booking::DepositCalculation
     include Yito::Model::Booking::CostCalculation

     extend BookingNotificationTemplates
     extend Yito::Model::Booking::Queries
     extend Yito::Model::Finder
     
     # --------------------------  CLASS METHODS -----------------------------------------------------------

     #
     # Calculate completed years between two dates
     #
     def self.completed_years(to_date, from_date)
       d = to_date
       a = d.year - from_date.year
       a = a - 1 if (from_date.month > d.month or
           (from_date.month >= d.month and from_date.day > d.day))
       a
     end

     #
     # Create a reservation from a shopping cart
     #
     def self.create_from_shopping_cart(shopping_cart, user_agent_data=nil, created_by_manager=false)

       booking = nil
       booking_driver_address = nil
       booking_item = nil
       booking_item_resource = nil
       booking_extra = nil

       begin
         Booking.transaction do
           # Create the booking
           booking = Booking.new(date_from: shopping_cart.date_from,
                          time_from: shopping_cart.time_from,
                          date_to: shopping_cart.date_to,
                          time_to: shopping_cart.time_to,
                          item_cost: shopping_cart.item_cost,
                          extras_cost: shopping_cart.extras_cost,
                          time_from_cost: shopping_cart.time_from_cost,
                          time_to_cost: shopping_cart.time_to_cost,
                          product_deposit_cost: shopping_cart.product_deposit_cost,
                          total_deposit: shopping_cart.total_deposit,
                          total_cost: shopping_cart.total_cost,
                          booking_amount: shopping_cart.booking_amount,
                          total_cost_includes_deposit: shopping_cart.total_cost_includes_deposit,
                          booking_amount_includes_deposit: shopping_cart.booking_amount_includes_deposit,
                          pay_now: shopping_cart.pay_now,
                          payment_method_id: shopping_cart.payment_method_id,
                          date_to_price_calculation: shopping_cart.date_to_price_calculation,
                          days: shopping_cart.days,
                          customer_name: shopping_cart.customer_name,
                          customer_surname: shopping_cart.customer_surname,
                          customer_email: shopping_cart.customer_email,
                          customer_phone: shopping_cart.customer_phone,
                          customer_mobile_phone: shopping_cart.customer_mobile_phone,
                          customer_language: shopping_cart.customer_language,
                          customer_document_id: shopping_cart.customer_document_id,
                          promotion_code: shopping_cart.promotion_code,
                          comments: shopping_cart.comments,
                          number_of_adults: shopping_cart.number_of_adults,
                          number_of_children: shopping_cart.number_of_children,
                          driver_name: shopping_cart.driver_name,
                          driver_surname: shopping_cart.driver_surname,
                          driver_document_id: shopping_cart.driver_document_id,
                          driver_document_id_date: shopping_cart.driver_document_id_date,
                          driver_document_id_expiration_date: shopping_cart.driver_document_id_expiration_date,
                          driver_origin_country: shopping_cart.driver_origin_country,
                          driver_date_of_birth: shopping_cart.driver_date_of_birth,
                          driver_age: shopping_cart.driver_age,
                          driver_driving_license_years: shopping_cart.driver_driving_license_years,
                          driver_age_allowed: shopping_cart.driver_age_allowed,
                          driver_age_cost: shopping_cart.driver_age_cost,
                          driver_age_deposit: shopping_cart.driver_age_deposit,
                          driver_under_age: shopping_cart.driver_under_age,
                          driver_age_rule_id: shopping_cart.driver_age_rule_id,
                          driver_age_rule_text: shopping_cart.driver_age_rule_text,
                          driver_age_rule_description: shopping_cart.driver_age_rule_description,
                          driver_age_rule_apply_if_prod_deposit: shopping_cart.driver_age_rule_apply_if_prod_deposit,
                          driver_age_rule_deposit: shopping_cart.driver_age_rule_deposit,
                          driver_driving_license_number: shopping_cart.driver_driving_license_number,
                          driver_driving_license_date: shopping_cart.driver_driving_license_date,
                          driver_driving_license_country: shopping_cart.driver_driving_license_country,
                          driver_driving_license_expiration_date: shopping_cart.driver_driving_license_expiration_date,
                          additional_driver_1_name: shopping_cart.additional_driver_1_name,
                          additional_driver_1_surname: shopping_cart.additional_driver_1_surname,
                          additional_driver_1_document_id: shopping_cart.additional_driver_1_document_id,
                          additional_driver_1_document_id_date: shopping_cart.additional_driver_1_document_id_date,
                          additional_driver_1_document_id_expiration_date: shopping_cart.additional_driver_1_document_id_expiration_date,
                          additional_driver_1_origin_country: shopping_cart.additional_driver_1_origin_country,
                          additional_driver_1_date_of_birth: shopping_cart.additional_driver_1_date_of_birth,
                          additional_driver_1_age: shopping_cart.additional_driver_1_age,
                          additional_driver_1_driving_license_number: shopping_cart.additional_driver_1_driving_license_number,
                          additional_driver_1_driving_license_date: shopping_cart.additional_driver_1_driving_license_date,
                          additional_driver_1_driving_license_country: shopping_cart.additional_driver_1_driving_license_country,
                          additional_driver_1_driving_license_expiration_date: shopping_cart.additional_driver_1_driving_license_expiration_date,
                          additional_driver_1_phone: shopping_cart.additional_driver_1_phone,
                          additional_driver_1_email: shopping_cart.additional_driver_1_email,       
                          additional_driver_2_name: shopping_cart.additional_driver_2_name,
                          additional_driver_2_surname: shopping_cart.additional_driver_2_surname,
                          additional_driver_2_document_id: shopping_cart.additional_driver_2_document_id,
                          additional_driver_2_document_id_date: shopping_cart.additional_driver_2_document_id_date,
                          additional_driver_2_document_id_expiration_date: shopping_cart.additional_driver_2_document_id_expiration_date,
                          additional_driver_2_origin_country: shopping_cart.additional_driver_2_origin_country,
                          additional_driver_2_date_of_birth: shopping_cart.additional_driver_2_date_of_birth,
                          additional_driver_2_age: shopping_cart.additional_driver_2_age,
                          additional_driver_2_driving_license_number: shopping_cart.additional_driver_2_driving_license_number,
                          additional_driver_2_driving_license_date: shopping_cart.additional_driver_2_driving_license_date,
                          additional_driver_2_driving_license_country: shopping_cart.additional_driver_2_driving_license_country,
                          additional_driver_2_driving_license_expiration_date: shopping_cart.additional_driver_2_driving_license_expiration_date,
                          additional_driver_2_phone: shopping_cart.additional_driver_2_phone,
                          additional_driver_2_email: shopping_cart.additional_driver_2_email,
                          additional_driver_3_name: shopping_cart.additional_driver_3_name,
                          additional_driver_3_surname: shopping_cart.additional_driver_3_surname,
                          additional_driver_3_document_id: shopping_cart.additional_driver_3_document_id,
                          additional_driver_3_document_id_date: shopping_cart.additional_driver_3_document_id_date,
                          additional_driver_3_document_id_expiration_date: shopping_cart.additional_driver_3_document_id_expiration_date,
                          additional_driver_3_origin_country: shopping_cart.additional_driver_3_origin_country,
                          additional_driver_3_date_of_birth: shopping_cart.additional_driver_3_date_of_birth,
                          additional_driver_3_age: shopping_cart.additional_driver_3_age,
                          additional_driver_3_driving_license_number: shopping_cart.additional_driver_3_driving_license_number,
                          additional_driver_3_driving_license_date: shopping_cart.additional_driver_3_driving_license_date,
                          additional_driver_3_driving_license_country: shopping_cart.additional_driver_3_driving_license_country,
                          additional_driver_3_driving_license_expiration_date: shopping_cart.additional_driver_3_driving_license_expiration_date,
                          additional_driver_3_phone: shopping_cart.additional_driver_3_phone,
                          additional_driver_3_email: shopping_cart.additional_driver_3_email,                                 
                          pickup_place: shopping_cart.pickup_place,
                          pickup_place_customer_translation: shopping_cart.pickup_place_customer_translation,
                          return_place: shopping_cart.return_place,
                          return_place_customer_translation: shopping_cart.return_place_customer_translation,
                          pickup_place_cost: shopping_cart.pickup_place_cost,
                          return_place_cost: shopping_cart.return_place_cost,
                          flight_company: shopping_cart.flight_company,
                          flight_number: shopping_cart.flight_number,
                          flight_time: shopping_cart.flight_time,
                          created_by_manager: created_by_manager,
                          sales_channel_code: shopping_cart.sales_channel_code,
                          destination_accommodation: shopping_cart.destination_accommodation)
           booking.init_user_agent_data(user_agent_data) unless user_agent_data.nil?
           booking.save

           if shopping_cart.driver_address
             booking_driver_address = LocationDataSystem::Address.new(
                      street: shopping_cart.driver_address.street,
                      number: shopping_cart.driver_address.number,
                      complement: shopping_cart.driver_address.complement,
                      city: shopping_cart.driver_address.city,
                      state: shopping_cart.driver_address.state,
                      country: shopping_cart.driver_address.country,
                      zip: shopping_cart.driver_address.zip)
             booking_driver_address.save
           else
             booking_driver_address = LocationDataSystem::Address.new
             booking_driver_address.save
           end

           booking.driver_address = booking_driver_address
           booking.save  

           # Create the items
           shopping_cart.items.each do |shopping_cart_item|
              booking_item = BookingLine.new(
                                            booking: booking,
                                            item_id: shopping_cart_item.item_id,
                                            item_description: shopping_cart_item.item_description,
                                            item_description_customer_translation: shopping_cart_item.item_description_customer_translation,
                                            optional: shopping_cart_item.optional,
                                            item_unit_cost_base: shopping_cart_item.item_unit_cost_base,
                                            item_unit_cost: shopping_cart_item.item_unit_cost,
                                            item_cost: shopping_cart_item.item_cost,
                                            quantity: shopping_cart_item.quantity,
                                            product_deposit_unit_cost: shopping_cart_item.product_deposit_unit_cost,
                                            product_deposit_cost: shopping_cart_item.product_deposit_cost)
               booking_item.save
             # Create the item resources
             shopping_cart_item.item_resources.each do |shopping_cart_item_resource|
               booking_item_resource = BookingLineResource.new(
                                            booking_line: booking_item,
                                            booking_item_category: shopping_cart_item_resource.booking_item_category,
                                            booking_item_reference: shopping_cart_item_resource.booking_item_reference,
                                            booking_item_stock_model: shopping_cart_item_resource.booking_item_stock_model,
                                            booking_item_stock_plate: shopping_cart_item_resource.booking_item_stock_plate,
                                            booking_item_characteristic_1: shopping_cart_item_resource.booking_item_characteristic_1,
                                            booking_item_characteristic_2: shopping_cart_item_resource.booking_item_characteristic_2,
                                            booking_item_characteristic_3: shopping_cart_item_resource.booking_item_characteristic_3,
                                            booking_item_characteristic_4: shopping_cart_item_resource.booking_item_characteristic_4,
                                            customer_height: shopping_cart_item_resource.customer_height,
                                            customer_weight: shopping_cart_item_resource.customer_weight,
                                            customer_2_height: shopping_cart_item_resource.customer_2_height,
                                            customer_2_weight: shopping_cart_item_resource.customer_2_weight,
                                            resource_user_name: shopping_cart_item_resource.resource_user_name,
                                            resource_user_surname: shopping_cart_item_resource.resource_user_surname,
                                            resource_user_document_id: shopping_cart_item_resource.resource_user_document_id,
                                            resource_user_phone: shopping_cart_item_resource.resource_user_phone,
                                            resource_user_email: shopping_cart_item_resource.resource_user_email,
                                            resource_user_2_name: shopping_cart_item_resource.resource_user_2_name,
                                            resource_user_2_surname: shopping_cart_item_resource.resource_user_2_surname,
                                            resource_user_2_document_id: shopping_cart_item_resource.resource_user_2_document_id,
                                            resource_user_2_phone: shopping_cart_item_resource.resource_user_2_phone,
                                            resource_user_2_email: shopping_cart_item_resource.resource_user_2_email)
               booking_item_resource.save
             end
           end

           # Create the extras
           shopping_cart.extras.each do |shopping_cart_extra|
              booking_extra = BookingExtra.new(booking: booking,
                                                  extra_id: shopping_cart_extra.extra_id,
                                                  extra_description: shopping_cart_extra.extra_description,
                                                  extra_description_customer_translation: shopping_cart_extra.extra_description_customer_translation,
                                                  extra_unit_cost: shopping_cart_extra.extra_unit_cost,
                                                  extra_cost: shopping_cart_extra.extra_cost,
                                                  quantity: shopping_cart_extra.quantity)
              booking_extra.save
           end

           booking.reload
           booking.send_new_booking_request_notifications

           # Create the newsfeed
           ::Yito::Model::Newsfeed::Newsfeed.create(category: 'booking',
                                                    action: 'new_booking',
                                                    identifier: booking.id.to_s,
                                                    description: BookingDataSystem.r18n.t.booking_news_feed.created_booking,
                                                    attributes_updated: booking.newsfeed_summary.to_json)

           booking

         end
       rescue DataMapper::SaveFailureError => error
         p "Error creating booking from shopping cart #{error} "
         p "Error in booking : #{booking.errors.full_messages.inspect}" if booking and booking.errors
         p "Error in booking driver address : #{booking_driver_address.errors.full_messages.inspect}" if booking_driver_address and booking_driver_address.errors
         p "Error in booking item : #{booking_item.errors.full_messages.inspect}" if booking_item and booking_item.errors
         p "Error in booking item resource : #{booking_item_resource.errors.full_messages.inspect}" if booking_item_resource and booking_item_resource.errors
         p "Error in booking extra : #{booking_extra.errors.full_messages.inspect}" if booking_extra and booking_extra.errors
         p "Error detail"
         raise error
       end


     end

     #
     # Get a booking by its free access id
     #
     # @parm [String] free access id
     # @return [Booking]
     #
     def self.get_by_free_access_id(free_id)
       first({:free_access_id => free_id})
     end

     #
     # Check if a date is in the payment cadence
     #
     def self.payment_cadence?(date_from,time_from=nil)

       conf_payment_cadence = SystemConfiguration::Variable.get_value('booking.payment_cadence', '0').to_i

       if time_from.nil?
         cadence_from = DateTime.parse("#{date_from.strftime('%Y-%m-%d')}T00:00:00")
       else
         cadence_from = DateTime.parse("#{date_from.strftime('%Y-%m-%d')}T#{time_from}")
       end
       cadence_payment = (cadence_from.to_time - DateTime.now.to_time) / 3600
       cadence_payment > conf_payment_cadence

     end

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
     # Before create hook (initilize fields)
     #
     before :create do |booking|
       booking.creation_date = Time.now if booking.creation_date.nil?
       booking.free_access_id = Digest::MD5.hexdigest("#{rand}#{customer_name}#{customer_surname}#{customer_email}#{rand}")
       booking.item_cost ||= 0
       booking.extras_cost ||= 0
       booking.time_from_cost ||= 0
       booking.time_to_cost ||= 0
       booking.product_deposit_cost ||= 0
       booking.total_deposit ||= 0
       booking.total_cost ||= 0
       booking.total_paid ||= 0
       booking.total_pending ||= 0
       booking.booking_amount ||= 0
       booking.total_pending = booking.total_cost - booking.total_paid
       booking.planning_color = '#66ff66' if booking.planning_color.nil?
       # Assign the rental location depending on the pickup place
       multiple_rental_locations = SystemConfiguration::Variable.get_value('booking.multiple_rental_locations', 'false').to_bool
       if multiple_rental_locations
         if _pickup_place = ::Yito::Model::Booking::PickupReturnPlace.first(name: booking.pickup_place) and
            !_pickup_place.rental_location.nil?
           booking.rental_location = _pickup_place.rental_location
         end
       end
     end

     #
     # Before save hook (clear leading and trailing whitespaces)
     #
     before :save do |booking|
       # Calculate days and date_to_price_calculation
       cadence_hours = SystemConfiguration::Variable.get_value('booking.hours_cadence',2).to_i
       booking.days = (booking.date_to - booking.date_from).to_i
       booking.date_to_price_calculation = booking.date_to

       begin
         _t_from = DateTime.strptime(booking.time_from,"%H:%M")
         _t_to = DateTime.strptime(booking.time_to,"%H:%M")
         if _t_to > _t_from
           hours_of_difference = (_t_to - _t_from).to_f.modulo(1) * 24
           if hours_of_difference > cadence_hours
             booking.days += 1
             booking.date_to_price_calculation += 1
           end
         end
       rescue
         p "Time from or time to are not valid #{booking.time_from} #{booking.time_from}"
       end

       # Strip spaces in customer information (search purposes)
       booking.customer_name.strip! unless booking.customer_name.nil?
       booking.customer_surname.strip! unless booking.customer_surname.nil?
       booking.customer_phone.strip! unless booking.customer_phone.nil?

     end

     #
     # Notify that a new booking has been received
     #
     def send_new_booking_request_notifications

       if pay_now
         notify_manager_pay_now
         notify_request_to_customer_pay_now
       else
         notify_manager
         notify_request_to_customer
       end

     end

     #
     # Notify that a booking has been confirmed 
     #
     def send_booking_confirmation_notifications

       notify_manager_confirmation
       notify_customer
       
     end
     
     # --------------------------- Reservation items management -----------------------------------------

     #
     # Add a booking line to the reservation
     #
     def add_booking_line(item_id, quantity)

       product_lines = self.booking_lines.select do |booking_line|
         booking_line.item_id == item_id
       end
       if product_lines.empty?
         if product = ::Yito::Model::Booking::BookingCategory.get(item_id)
           product_customer_translation = product.translate(customer_language)
           product_unit_cost = product.unit_price(self.date_from, self.days, nil, self.sales_channel_code)
           product_deposit_cost = product.deposit
           transaction do
             # Create booking line
             booking_line = BookingDataSystem::BookingLine.new
             booking_line.booking = self
             booking_line.item_id = item_id
             booking_line.item_description = product.name
             booking_line.item_description_customer_translation = (product_customer_translation.nil? ? product.name : product_customer_translation.name)
             booking_line.item_unit_cost_base = product_unit_cost
             booking_line.item_unit_cost = product_unit_cost
             booking_line.item_cost = product_unit_cost * quantity
             booking_line.quantity = quantity
             booking_line.product_deposit_unit_cost = product_deposit_cost
             booking_line.product_deposit_cost = product_deposit_cost * quantity
             booking_line.save
             # Create booking line resources
             (1..quantity).each do |resource_number|
               booking_line_resource = BookingDataSystem::BookingLineResource.new
               booking_line_resource.booking_line = booking_line
               booking_line_resource.save
             end
             # Update booking cost
             self.item_cost += (product_unit_cost * quantity)
             self.product_deposit_cost += (product_deposit_cost * quantity)
             self.calculate_cost(false, false)
             self.save
             # Create newsfeed
             ::Yito::Model::Newsfeed::Newsfeed.create(category: 'booking',
                                            action: 'add_booking_line',
                                            identifier: self.id.to_s,
                                            description: BookingDataSystem.r18n.t.booking_news_feed.created_booking_line(item_id, quantity),
                                            attributes_updated: {item_id: item_id, quantity: quantity}.merge({booking: newsfeed_summary}).to_json)
           end
         end
       end
     end

     #
     # Add a booking extra to the reservation
     #
     def add_booking_extra(extra_id, quantity)

       booking_extras = self.booking_extras.select do |booking_extra|
         booking_extra.extra_id == extra_id
       end

       if booking_extras.empty?
         if extra = ::Yito::Model::Booking::BookingExtra.get(extra_id)
           extra_translation = extra.translate(customer_language)
           booking_deposit = SystemConfiguration::Variable.get_value('booking.deposit', 0).to_i
           extra_unit_cost = extra.unit_price(self.date_from, self.days)
           transaction do
             # Create the booking extra line
             booking_extra = BookingDataSystem::BookingExtra.new
             booking_extra.booking = self
             booking_extra.extra_id = extra_id
             booking_extra.extra_description = extra.name
             booking_extra.extra_description_customer_translation = extra_translation.nil? ? extra.name : extra_translation.name
             booking_extra.quantity = quantity
             booking_extra.extra_unit_cost = extra_unit_cost
             booking_extra.extra_cost = extra_unit_cost * quantity
             booking_extra.save
             # Updates the booking
             self.extras_cost += (extra_unit_cost * quantity)
             self.calculate_cost(false, false)
             self.save
             # Create newsfeed
             ::Yito::Model::Newsfeed::Newsfeed.create(category: 'booking',
                                            action: 'add_booking_extra',
                                            identifier: self.id.to_s,
                                            description: BookingDataSystem.r18n.t.booking_news_feed.created_booking_extra(extra_id, quantity),
                                            attributes_updated: {extra_id: extra_id, quantity: quantity}.merge({booking: newsfeed_summary}).to_json)
           end
         end
       end

     end

     #
     # Destroy a booking extra
     #
     def destroy_booking_extra(extra_id)

       booking_extras = self.booking_extras.select do |booking_extra|
         booking_extra.extra_id == extra_id
       end

       if booking_extra = booking_extras.first
         transaction do
           self.extras_cost -= booking_extra.extra_cost
           self.calculate_cost(false, false)
           self.save
           booking_extra.destroy
           # Create newsfeed
           ::Yito::Model::Newsfeed::Newsfeed.create(category: 'booking',
                                          action: 'destroy_booking_extra',
                                          identifier: self.id.to_s,
                                          description: BookingDataSystem.r18n.t.booking_news_feed.destroyed_booking_extra(extra_id),
                                          attributes_updated: {extra_id: item_id, quantity: quantity}.merge({booking: newsfeed_summary}).to_json)
         end
         self.reload
       end

     end

     #
     # Add a booking charge
     #
     def add_booking_charge(date, amount, payment_method_id)

       transaction do
         charge = Payments::Charge.new
         charge.date = date
         charge.amount = amount
         charge.payment_method_id = payment_method_id
         charge.status = :pending
         charge.currency = SystemConfiguration::Variable.get_value('payments.default_currency', 'EUR')
         charge.save
         booking_charge = BookingDataSystem::BookingCharge.new
         booking_charge.booking = self
         booking_charge.charge = charge
         booking_charge.save
         charge.update(:status => :done)
         self.reload
         # Create newsfeed
         ::Yito::Model::Newsfeed::Newsfeed.create(category: 'booking',
                                        action: 'add_booking_charge',
                                        identifier: self.id.to_s,
                                        description: BookingDataSystem.r18n.t.booking_news_feed.added_booking_charge(".2f" % amount, payment_method_id),
                                        attributes_updated: {date: date, amount: amount, payment_method_id: payment_method_id}.merge({booking: newsfeed_summary}).to_json)
       end

     end

     #
     # Destroy a booking charge
     #
     def destroy_booking_charge(charge_id)

       if booking_charge = BookingDataSystem::BookingCharge.first(:booking_id => self.id,
                                                                  :charge_id => charge_id)
         charge = booking_charge.charge
         transaction do
           if charge.status == :done
             self.total_paid -= charge.amount
             self.total_pending += charge.amount
             self.save
           end
           charge.destroy
           booking_charge.destroy
           # Create newsfeed
           ::Yito::Model::Newsfeed::Newsfeed.create(category: 'booking',
                                          action: 'destroy_booking_charge',
                                          identifier: self.id.to_s,
                                          description: BookingDataSystem.r18n.t.booking_news_feed.destroyed_booking_charge(".2f" % charge.amount, charge.payment_method_id),
                                          attributes_updated: {amount: charge.amount, payment_method_id: charge.payment_method_id}.to_json)
         end
         self.reload
       end

     end

     # -----------------------------------------------------------------------------------------------------------

     #
     # Get the category of the reserved items
     #
     def category
       booking_lines and booking_lines.size > 0 ? ::Yito::Model::Booking::BookingCategory.get(booking_lines[0].item_id) : nil
     end

     #
     # Check if the reservation has expired
     #
     def expired?
         conf_item_hold_time = SystemConfiguration::Variable.get_value('booking.item_hold_time', '0').to_i
         hold_time_diff_in_hours = ((DateTime.now.to_time - self.creation_date.to_time).to_f * 24).to_i
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
           diff_in_hours = ((_date_from.to_time - self.creation_date.to_time).to_f * 24).to_i
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
     # Check if the booking deposit can be paid
     #
     def can_pay_deposit?
       self.can_pay? and self.total_paid == 0
     end

     #
     # Check if the booking total can be paid
     #
     def can_pay_total?
       self.can_pay? and self.total_paid == 0 and SystemConfiguration::Variable.get_value('booking.allow_total_payment','false').to_bool
     end

     #
     # Check if the booking pending amout can be paid
     #
     def can_pay_pending?
       sel.can_pay? and self.total_paid > 0
     end


     alias_method :is_expired, :expired?
     alias_method :can_pay, :can_pay?

     #
     # Get the deposit amount
     #
     def booking_deposit

       #(total_cost * SystemConfiguration::Variable.get_value('booking.deposit', '0').to_i / 100).round
       booking_amount

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
                      booking_deposit #(total_cost * SystemConfiguration::Variable.get_value('booking.deposit', '0').to_i / 100).round
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
         transaction do
           self.status = :confirmed
           self.save
           # Assign available stock
           assign_available_stock if SystemConfiguration::Variable.get_value('booking.assignation.automatic_resource_assignation', 'false').to_bool
           # Create newsfeed
           ::Yito::Model::Newsfeed::Newsfeed.create(category: 'booking',
                                                    action: 'confirm_booking',
                                                    identifier: self.id.to_s,
                                                    description: BookingDataSystem.r18n.t.confirmed_booking)
         end
         send_booking_confirmation_notifications
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
         transaction do
           update(:status => :confirmed)
           # Assign available stock
           assign_available_stock if SystemConfiguration::Variable.get_value('booking.assignation.automatic_resource_assignation', 'false').to_bool
           # Create newsfeed
           ::Yito::Model::Newsfeed::Newsfeed.create(category: 'booking',
                                          action: 'confirm_booking',
                                          identifier: self.id.to_s,
                                          description: BookingDataSystem.r18n.t.confirmed_booking)
         end
         send_booking_confirmation_notifications
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
         transaction do
           update(:status => :in_progress)
           # Create newsfeed
           ::Yito::Model::Newsfeed::Newsfeed.create(category: 'booking',
                                          action: 'pickup_item',
                                          identifier: self.id.to_s,
                                          description: BookingDataSystem.r18n.t.picked_up_item)
         end  
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
         transaction do
           update(:status => :done)
           # Create newsfeed
           ::Yito::Model::Newsfeed::Newsfeed.create(category: 'booking',
                                          action: 'return_item',
                                          identifier: self.id.to_s,
                                          description: BookingDataSystem.r18n.t.returned_item)
         end  
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
           # Create newsfeed
           ::Yito::Model::Newsfeed::Newsfeed.create(category: 'booking',
                                          action: 'cancel_booking',
                                          identifier: self.id.to_s,
                                          description: BookingDataSystem.r18n.t.canceled_booking)
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

     #
     # Get a newsfeed summary
     #
     def newsfeed_summary
       items = []
       extras = []
       booking_lines.each do |booking_item|
         items << {item_id: booking_item.item_id,
                   item_unit_cost: booking_item.item_unit_cost,
                   item_cost: booking_item.item_cost,
                   quantity: booking_item.quantity,
                   product_deposit_unit_cost: booking_item.product_deposit_unit_cost,
                   product_deposit_cost: booking_item.product_deposit_cost}
       end
       booking_extras.each do |booking_extra|
         extras << {extra_id: booking_extra.extra_id,
                    extra_unit_cost: booking_extra.extra_unit_cost,
                    extra_cost: booking_extra.extra_cost,
                    quantity: booking_extra.quantity}
       end
       {items: items,
        extras: extras,
        status: status,
        item_cost: item_cost,
        extras_cost: extras_cost,
        time_from_cost: time_from_cost,
        time_to_cost: time_to_cost,
        pickup_place_cost: pickup_place_cost,
        return_place_cost: return_place_cost,
        driver_age_cost: driver_age_cost,
        total_cost: total_cost,
        total_paid: total_paid,
        total_pending: total_pending,
        booking_amount: booking_amount,
        product_deposit_cost: product_deposit_cost,
        driver_age_deposit: driver_age_deposit,
        total_deposit: total_deposit}
     end

     #
     # Assign available stock to unassigned items
     #
     def assign_available_stock

       stock_detail, category_occupation = BookingDataSystem::Booking.resources_occupation(self.date_from, self.date_to)

       transaction do

         booking_lines.each do |booking_line|
           booking_line.booking_line_resources.each do |booking_line_resource|
             if booking_line_resource.booking_item_reference.nil?
               if booking_item_reference = category_occupation[booking_line.item_id][:available_assignable_stock].first and !booking_item_reference.nil?
                 booking_line_resource.assign_resource(booking_item_reference)
                 category_occupation[booking_line.item_id][:available_assignable_stock].delete_at(0)
               end
             end
           end
         end

       end

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

       charge_attributes = {:date => Time.now,
                            :amount => charge_amount,
                            :payment_method_id => charge_payment_method_id,
                            :currency => SystemConfiguration::Variable.get_value('payments.default_currency', 'EUR')}
       charge_attributes.merge!({:sales_channel_code => self.sales_channel_code}) unless self.sales_channel_code.nil?

       charge = Payments::Charge.create(charge_attributes)
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
