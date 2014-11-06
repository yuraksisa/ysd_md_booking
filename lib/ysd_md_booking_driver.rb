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
       model.property :driver_document_id, String, :field => 'driver_document_id', :length => 15
       model.property :driver_date_of_birth, DateTime, :field => 'driver_date_of_birth'
       model.property :driver_age_cost, DataMapper::Property::Decimal, :scale => 2, :precision => 10, :default => 0

       model.property :driver_driving_license_number, String, :field => 'driver_driving_license_number', :length => 15
       model.property :driver_driving_license_date, DateTime, :field => 'driver_driving_license_date'
       model.property :driver_driving_license_country, String, :field => 'driver_driving_license_country', :length => 50
      
     end
     
     if model.respond_to?(:belongs_to)
       model.belongs_to :driver_address, 'LocationDataSystem::Address', :required => false # The driver address
     end

   end
  end #BookingDriver  

end #BookingDataSystem