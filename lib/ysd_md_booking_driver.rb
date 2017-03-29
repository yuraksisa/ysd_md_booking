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
       model.property :driver_date_of_birth, DateTime, :field => 'driver_date_of_birth'
       model.property :driver_age_cost, DataMapper::Property::Decimal, :scale => 2, :precision => 10, :default => 0

       model.property :driver_driving_license_number, String, :field => 'driver_driving_license_number', :length => 50
       model.property :driver_driving_license_date, DateTime, :field => 'driver_driving_license_date'
       model.property :driver_driving_license_country, String, :field => 'driver_driving_license_country', :length => 50

       # Additional drivers
       model.property :additional_driver_1_name, String, :length => 40
       model.property :additional_driver_1_surname, String, :length => 40
       model.property :additional_driver_1_date_of_birth, DateTime
       model.property :additional_driver_1_driving_license_number, String, :length => 50
       model.property :additional_driver_1_driving_license_date, DateTime
       model.property :additional_driver_1_document_id, String, :length => 50
       model.property :additional_driver_1_phone, String, :length => 15
       model.property :additional_driver_1_email, String, :length => 40

       model.property :additional_driver_2_name, String, :length => 40
       model.property :additional_driver_2_surname, String, :length => 40
       model.property :additional_driver_2_date_of_birth, DateTime
       model.property :additional_driver_2_driving_license_number, String, :length => 50
       model.property :additional_driver_2_document_id, String, :length => 50
       model.property :additional_driver_2_driving_license_date, DateTime
       model.property :additional_driver_2_phone, String, :length => 15
       model.property :additional_driver_2_email, String, :length => 40

       model.property :additional_driver_3_name, String, :length => 40
       model.property :additional_driver_3_surname, String, :length => 40
       model.property :additional_driver_3_date_of_birth, DateTime
       model.property :additional_driver_3_driving_license_number, String, :length => 50
       model.property :additional_driver_3_document_id, String, :length => 50
       model.property :additional_driver_3_driving_license_date, DateTime
       model.property :additional_driver_3_phone, String, :length => 15
       model.property :additional_driver_3_email, String, :length => 40

     end
     
     if model.respond_to?(:belongs_to)
       model.belongs_to :driver_address, 'LocationDataSystem::Address', :required => false # The driver address
     end
      
     if model.respond_to?(:after)
       model.after :destroy do
         driver_address.destroy unless driver_address.nil?
       end
     end  

   end
  end #BookingDriver  

end #BookingDataSystem