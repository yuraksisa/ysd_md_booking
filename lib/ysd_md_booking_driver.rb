require 'ysd_md_location' unless defined?LocationDataSystem::Address
module BookingDataSystem
  #
  # Represent the booking driver
  #
  module BookingDriver

    def self.included(model)
     
     if model.respond_to?(:property)

       model.property :driver_name, String, :field => 'driver_name', :length => 40
       model.property :driver_surname, String, :field => 'driver_surname', :length => 40
       model.property :driver_document_id, String, :field => 'driver_document_id', :length => 50
       model.property :driver_document_id_date, DateTime
       model.property :driver_document_id_expiration_date, DateTime
       model.property :driver_origin_country, String, :length => 80
       model.property :driver_date_of_birth, DateTime, :field => 'driver_date_of_birth'

       model.property :driver_driving_license_number, String, :field => 'driver_driving_license_number', :length => 50
       model.property :driver_driving_license_date, DateTime, :field => 'driver_driving_license_date'
       model.property :driver_driving_license_country, String, :field => 'driver_driving_license_country', :length => 50
       model.property :driver_driving_license_expiration_date, DateTime

       # Driver age and driving license calculated fields
       model.property :driver_age, Integer
       model.property :driver_driving_license_years, Integer
       model.property :driver_under_age, DataMapper::Property::Boolean
       model.property :driver_age_allowed, DataMapper::Property::Boolean
       model.property :driver_age_cost, DataMapper::Property::Decimal, :scale => 2, :precision => 10, :default => 0
       model.property :driver_age_deposit, DataMapper::Property::Decimal, scale: 2, precision: 10, default: 0
       model.property :driver_age_rule_id, Integer
       model.property :driver_age_rule_description, String, length: 256
       model.property :driver_age_rule_text, DataMapper::Property::Text
       model.property :driver_age_rule_apply_if_prod_deposit, DataMapper::Property::Boolean, default: false
       model.property :driver_age_rule_deposit, DataMapper::Property::Decimal, scale: 2, precision: 10, default: 0

       # Additional drivers
       model.property :additional_driver_1_name, String, :length => 40
       model.property :additional_driver_1_surname, String, :length => 40
       model.property :additional_driver_1_date_of_birth, DateTime
       model.property :additional_driver_1_age, Integer
       model.property :additional_driver_1_driving_license_number, String, :length => 50
       model.property :additional_driver_1_driving_license_date, DateTime
       model.property :additional_driver_1_driving_license_country, String, :length => 50
       model.property :additional_driver_1_driving_license_expiration_date, DateTime
       model.property :additional_driver_1_document_id, String, :length => 50
       model.property :additional_driver_1_document_id_date, DateTime
       model.property :additional_driver_1_document_id_expiration_date, DateTime
       model.property :additional_driver_1_phone, String, :length => 15
       model.property :additional_driver_1_email, String, :length => 40
       model.property :additional_driver_1_origin_country, String, :length => 80

       model.property :additional_driver_2_name, String, :length => 40
       model.property :additional_driver_2_surname, String, :length => 40
       model.property :additional_driver_2_date_of_birth, DateTime
       model.property :additional_driver_2_age, Integer
       model.property :additional_driver_2_driving_license_number, String, :length => 50
       model.property :additional_driver_2_driving_license_date, DateTime
       model.property :additional_driver_2_driving_license_country, String, :length => 50
       model.property :additional_driver_2_driving_license_expiration_date, DateTime
       model.property :additional_driver_2_document_id, String, :length => 50
       model.property :additional_driver_2_document_id_date, DateTime
       model.property :additional_driver_2_document_id_expiration_date, DateTime
       model.property :additional_driver_2_phone, String, :length => 15
       model.property :additional_driver_2_email, String, :length => 40
       model.property :additional_driver_2_origin_country, String, :length => 80

       model.property :additional_driver_3_name, String, :length => 40
       model.property :additional_driver_3_surname, String, :length => 40
       model.property :additional_driver_3_date_of_birth, DateTime
       model.property :additional_driver_3_age, Integer
       model.property :additional_driver_3_driving_license_number, String, :length => 50
       model.property :additional_driver_3_driving_license_date, DateTime
       model.property :additional_driver_3_driving_license_country, String, :length => 50
       model.property :additional_driver_3_driving_license_expiration_date, DateTime
       model.property :additional_driver_3_document_id, String, :length => 50
       model.property :additional_driver_3_document_id_date, DateTime
       model.property :additional_driver_3_document_id_expiration_date, DateTime
       model.property :additional_driver_3_phone, String, :length => 15
       model.property :additional_driver_3_email, String, :length => 40
       model.property :additional_driver_3_origin_country, String, :length => 80

     end
     
     if model.respond_to?(:belongs_to)
       model.belongs_to :driver_address, 'LocationDataSystem::Address', :required => false # The driver address
     end

     #
     # After destroy the booking destroy the driver address instance
     #
     if model.respond_to?(:after)
       model.after :destroy do
         driver_address.destroy unless driver_address.nil?
       end
     end

     def calculate_additional_drivers_years
       driver.addional_driver_1_age = BookingDataSystem::Booking.completed_years(self.date_from. self.additional_driver_1_date_of_birth)
       driver.addional_driver_2_age = BookingDataSystem::Booking.completed_years(self.date_from. self.additional_driver_2_date_of_birth)
       driver.addional_driver_3_age = BookingDataSystem::Booking.completed_years(self.date_from. self.additional_driver_3_date_of_birth)
     end

     #
     # Update driver age deposit
     #
     def update_driver_age_deposit(driver_age_deposit)

       if self.product_deposit_cost == 0 || self.driver_age_rule_apply_if_prod_deposit
         transaction do
           old_driver_age_deposit = self.driver_age_deposit
           self.driver_age_deposit = driver_age_deposit
           self.total_deposit = self.product_deposit_cost + driver_age_deposit
           self.calculate_cost(false, false)
           self.save
           # Create newsfeed
           ::Yito::Model::Newsfeed::Newsfeed.create(category: 'booking',
                                          action: 'updated_driver_age_deposit',
                                          identifier: self.id.to_s,
                                          description: BookingDataSystem.r18n.t.booking_news_feed.updated_driver_age_deposit("%.2f" % driver_age_deposit, "%.2f" % old_driver_age_deposit),
                                          attributes_updated: {driver_age_deposit: self.driver_age_deposit, total_deposit: self.total_deposit,
                                                               total_cost: self.total_cost, total_pending: self.total_pending, booking_amount: self.booking_amount}.to_json)
         end
       end

     end

     #
     # Update driver dates and apply
     #
     def update_driver_dates(date_of_birth, driving_license_date)
        transaction do
          self.driver_date_of_birth = date_of_birth
          self.driver_driving_license_date = driving_license_date
          self.driver_age = BookingDataSystem::Booking.completed_years(self.date_from, self.driver_date_of_birth)
          self.driver_driving_license_years = BookingDataSystem::Booking.completed_years(self.date_from, self.driver_driving_license_date)
          self.calculate_cost
          self.save
          # Create newsfeed
          ::Yito::Model::Newsfeed::Newsfeed.create(category: 'booking',
                                         action: 'updated_driver_dates',
                                         identifier: self.id.to_s,
                                         description: BookingDataSystem.r18n.t.booking_news_feed.updated_driver_dates(date_of_birth, driving_license_date),
                                         attributes_updated: {driver_date_of_birth: self.driver_date_of_birth, driver_driving_license_date: self.driver_driving_license_date,
                                                              total_cost: self.total_cost, total_pending: self.total_pending, booking_amount: self.booking_amount}.to_json)
        end
     end

   end
  end #BookingDriver  

end #BookingDataSystem