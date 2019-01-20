module Yito
  module Model
    module Booking
      module Concerns
      	#
      	# Manage the customer information
      	#
        module Customer

		  def self.included(model)

             model.belongs_to :customer, 'Yito::Model::Customers::Customer', required: false, child_key: [:customer_id], parent_key: [:id]

		     #
		     # Update from customer
		     # 
		     def update_data_from_customer

		        if customer
		          # Update basic data
		          self.customer_name = customer.name
		          self.customer_surname = customer.surname
		          self.customer_document_id = customer.document_id
		          self.customer_email = customer.email
		          self.customer_phone = customer.phone_number
		          self.customer_mobile_phone = customer.mobile_phone
		          self.customer_language = customer.language         
		       
		          # Driver data
		          self.driver_document_id_date = customer.document_id_date
		          self.driver_document_id_expiration_date = customer.document_id_expiration_date 
		          self.driver_origin_country = customer.origin_country
		          self.driver_date_of_birth = customer.date_of_birth
		          self.driver_driving_license_number = customer.driving_license_number
		          self.driver_driving_license_date = customer.driving_license_date
		          self.driver_driving_license_country = customer.driving_license_country
		          self.driver_driving_license_expiration_date = customer.driving_license_expiration_date

		          # Driver address
		          self.driver_address = LocationDataSystem::Address.new unless self.driver_address
		          self.driver_address.street = customer.address.street 
		          self.driver_address.number = customer.address.number
		          self.driver_address.complement = customer.address.complement
		          self.driver_address.city = customer.address.city
		          self.driver_address.state = customer.address.state
		          self.driver_address.country = customer.address.country
		          self.driver_address.zip = customer.address.zip

		          # Additional drivers
		          self.additional_driver_1_name = customer.additional_driver_1_name
		          self.additional_driver_1_surname = customer.additional_driver_1_surname
		          self.additional_driver_1_date_of_birth = customer.additional_driver_1_date_of_birth
		          self.additional_driver_1_driving_license_number = customer.additional_driver_1_driving_license_number
		          self.additional_driver_1_driving_license_date = customer.additional_driver_1_driving_license_date
		          self.additional_driver_1_driving_license_country = customer.additional_driver_1_driving_license_country
		          self.additional_driver_1_driving_license_expiration_date = customer.additional_driver_1_driving_license_expiration_date
		          self.additional_driver_1_document_id = customer.additional_driver_1_document_id
		          self.additional_driver_1_document_id_date = customer.additional_driver_1_document_id_date
		          self.additional_driver_1_document_id_expiration_date = customer.additional_driver_1_document_id_expiration_date
		          self.additional_driver_1_phone = customer.additional_driver_1_phone
		          self.additional_driver_1_email = customer.additional_driver_1_email
		          self.additional_driver_1_origin_country = customer.additional_driver_1_origin_country
		          self.additional_driver_2_name = customer.additional_driver_2_name
		          self.additional_driver_2_surname = customer.additional_driver_2_surname
		          self.additional_driver_2_date_of_birth = customer.additional_driver_2_date_of_birth
		          self.additional_driver_2_driving_license_number = customer.additional_driver_2_driving_license_number
		          self.additional_driver_2_driving_license_date = customer.additional_driver_2_driving_license_date
		          self.additional_driver_2_driving_license_country = customer.additional_driver_2_driving_license_country
		          self.additional_driver_2_driving_license_expiration_date = customer.additional_driver_2_driving_license_expiration_date
		          self.additional_driver_2_document_id = customer.additional_driver_2_document_id
		          self.additional_driver_2_document_id_date = customer.additional_driver_2_document_id_date
		          self.additional_driver_2_document_id_expiration_date = customer.additional_driver_2_document_id_expiration_date
		          self.additional_driver_2_phone = customer.additional_driver_2_phone
		          self.additional_driver_2_email = customer.additional_driver_2_email
		          self.additional_driver_2_origin_country = customer.additional_driver_2_origin_country
		          self.additional_driver_3_name = customer.additional_driver_3_name
		          self.additional_driver_3_surname = customer.additional_driver_3_surname
		          self.additional_driver_3_date_of_birth = customer.additional_driver_3_date_of_birth
		          self.additional_driver_3_driving_license_number = customer.additional_driver_3_driving_license_number
		          self.additional_driver_3_driving_license_date = customer.additional_driver_3_driving_license_date
		          self.additional_driver_3_driving_license_country = customer.additional_driver_3_driving_license_country
		          self.additional_driver_3_driving_license_expiration_date = customer.additional_driver_3_driving_license_expiration_date
		          self.additional_driver_3_document_id = customer.additional_driver_3_document_id
		          self.additional_driver_3_document_id_date = customer.additional_driver_3_document_id_date
		          self.additional_driver_3_document_id_expiration_date = customer.additional_driver_3_document_id_expiration_date
		          self.additional_driver_3_phone = customer.additional_driver_3_phone
		          self.additional_driver_3_email = customer.additional_driver_3_email
		          self.additional_driver_3_origin_country = customer.additional_driver_3_origin_country
		        end

		     end 

		     #
		     # Update customer data
		     #
		     def update_customer_data

		       if self.customer
		         self.customer.name = self.customer_name
		         self.customer.surname = self.customer_surname
		         self.customer.document_id = self.driver_document_id
		         self.customer.email = self.customer_email
		         self.customer.phone_number = self.customer_phone
		         self.customer.mobile_phone = self.customer_mobile_phone
		         self.customer.language = self.customer_language
		         self.customer.address = LocationDataSystem::Address.new unless customer.address
		         self.customer.invoice_address = LocationDataSystem::Address.new unless customer.invoice_address
		         if self.driver_address
		           self.customer.address.street = customer.invoice_address.street = self.driver_address.street 
		           self.customer.address.number = customer.invoice_address.number = self.driver_address.number
		           self.customer.address.complement = customer.invoice_address.complement = self.driver_address.complement
		           self.customer.address.city = customer.invoice_address.city = self.driver_address.city
		           self.customer.address.state = customer.invoice_address.state = self.driver_address.state
		           self.customer.address.country = customer.invoice_address.country = self.driver_address.country
		           self.customer.address.zip = customer.invoice_address.zip = self.driver_address.zip
		         end
		         # Driver data
		         self.customer.document_id_date = self.driver_document_id_date
		         self.customer.document_id_expiration_date = self.driver_document_id_expiration_date
		         self.customer.origin_country = self.driver_origin_country
		         self.customer.date_of_birth = self.driver_date_of_birth
		         self.customer.driving_license_number = self.driver_driving_license_number
		         self.customer.driving_license_date = self.driver_driving_license_date
		         self.customer.driving_license_country = self.driver_driving_license_country
		         self.customer.driving_license_expiration_date = self.driver_driving_license_expiration_date
		         # Additional drivers
		         self.customer.additional_driver_1_name = self.additional_driver_1_name
		         self.customer.additional_driver_1_surname = self.additional_driver_1_surname
		         self.customer.additional_driver_1_date_of_birth = self.additional_driver_1_date_of_birth
		         self.customer.additional_driver_1_driving_license_number = self.additional_driver_1_driving_license_number
		         self.customer.additional_driver_1_driving_license_date = self.additional_driver_1_driving_license_date
		         self.customer.additional_driver_1_driving_license_country = self.additional_driver_1_driving_license_country
		         self.customer.additional_driver_1_driving_license_expiration_date = self.additional_driver_1_driving_license_expiration_date
		         self.customer.additional_driver_1_document_id = self.additional_driver_1_document_id
		         self.customer.additional_driver_1_document_id_date = self.additional_driver_1_document_id_date
		         self.customer.additional_driver_1_document_id_expiration_date = self.additional_driver_1_document_id_expiration_date
		         self.customer.additional_driver_1_phone = self.additional_driver_1_phone
		         self.customer.additional_driver_1_email = self.additional_driver_1_email
		         self.customer.additional_driver_1_origin_country = self.additional_driver_1_origin_country
		         self.customer.additional_driver_2_name = self.additional_driver_2_name
		         self.customer.additional_driver_2_surname = self.additional_driver_2_surname
		         self.customer.additional_driver_2_date_of_birth = self.additional_driver_2_date_of_birth
		         self.customer.additional_driver_2_driving_license_number = self.additional_driver_2_driving_license_number
		         self.customer.additional_driver_2_driving_license_date = self.additional_driver_2_driving_license_date
		         self.customer.additional_driver_2_driving_license_country = self.additional_driver_2_driving_license_country
		         self.customer.additional_driver_2_driving_license_expiration_date = self.additional_driver_2_driving_license_expiration_date
		         self.customer.additional_driver_2_document_id = self.additional_driver_2_document_id
		         self.customer.additional_driver_2_document_id_date = self.additional_driver_2_document_id_date
		         self.customer.additional_driver_2_document_id_expiration_date = self.additional_driver_2_document_id_expiration_date
		         self.customer.additional_driver_2_phone = self.additional_driver_2_phone
		         self.customer.additional_driver_2_email = self.additional_driver_2_email
		         self.customer.additional_driver_2_origin_country = self.additional_driver_2_origin_country
		         self.customer.additional_driver_3_name = self.additional_driver_3_name
		         self.customer.additional_driver_3_surname = self.additional_driver_3_surname
		         self.customer.additional_driver_3_date_of_birth = self.additional_driver_3_date_of_birth
		         self.customer.additional_driver_3_driving_license_number = self.additional_driver_3_driving_license_number
		         self.customer.additional_driver_3_driving_license_date = self.additional_driver_3_driving_license_date
		         self.customer.additional_driver_3_driving_license_country = self.additional_driver_3_driving_license_country
		         self.customer.additional_driver_3_driving_license_expiration_date = self.additional_driver_3_driving_license_expiration_date
		         self.customer.additional_driver_3_document_id = self.additional_driver_3_document_id
		         self.customer.additional_driver_3_document_id_date = self.additional_driver_3_document_id_date
		         self.customer.additional_driver_3_document_id_expiration_date = self.additional_driver_3_document_id_expiration_date
		         self.customer.additional_driver_3_phone = self.additional_driver_3_phone
		         self.customer.additional_driver_3_email = self.additional_driver_3_email
		         self.customer.additional_driver_3_origin_country = self.additional_driver_3_origin_country

		       end 

		     end 


		     #
		     # Create a customer from reservation name
		     #
		     def create_customer

		       return customer if customer

		       self.customer = ::Yito::Model::Customers::Customer.new
		       self.customer.customer_type = :individual
		       update_customer_data
		       self.customer.save

		       return customer
		     end 

		  end

        end
      end
    end
  end
end