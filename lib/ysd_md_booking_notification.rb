require 'ysd_service_postal' unless defined?ServicePostal
require 'ysd_md_cms' unless defined?ContentManagerSystem::Template
require 'dm-core'
require 'delayed_job'

module BookingDataSystem
  
  module Notifier
    
    #
    # Notifies the manager that a new request has been received
    #
    def self.notify_manager(to, subject, message, booking_id)
      
      PostalService.post(build_message(message).merge(:to => to, :subject => subject))
  
      if booking = BookingDataSystem::Booking.get(booking_id)
        booking.update(:manager_notification_sent => true)
      end

    end
    
    #
    # Notifies the customer that a new request has been received
    #
    def self.notify_request_to_customer(to, subject, message, booking_id)

      PostalService.post(build_message(message).merge(:to => to, :subject => subject))

      if booking = BookingDataSystem::Booking.get(booking_id)
        booking.update(:customer_req_notification_sent => true)
      end

    end
    
    #
    # Notifies the customer when the booking is confirmed 
    #
    def self.notify_customer(to, subject, message, booking_id)

      PostalService.post(build_message(message).merge(:to => to, :subject => subject))

      if booking = BookingDataSystem::Booking.get(booking_id)
        booking.update(:customer_notification_sent => true)
      end

    end

    def self.build_message(message)

      post_message = {}
      
      if message.match /<\w+>/
        post_message.store(:html_body, message) 
      else
        post_message.store(:body, message)
      end 
      
      return post_message

    end

  end

  #
  # Send notifications to the booking manager and to the customer
  #
  #
  module BookingNotifications
    
    def self.included(model)
     
     if model.respond_to?(:property)
       model.property :customer_notification_sent, DataMapper::Property::Boolean, :field => 'customer_notification_sent'
       model.property :customer_req_notification_sent, DataMapper::Property::Boolean, :field => 'customer_req_notification_sent', :default => false
       model.property :manager_notification_sent, DataMapper::Property::Boolean, :field => 'manager_notification_sent'
     end

    end

    #
    # Notifies by email the booking manager that a new booking have been received
    # 
    # The manager address can be set up on booking.notification_email variable
    #
    # It allows to define a custom template naming it as booking_manager_notification
    # 
    def notify_manager

      if notification_email = SystemConfiguration::Variable.get_value('booking.notification_email')
        bmn_template = ContentManagerSystem::Template.first(:name => 'booking_manager_notification')

        template = if bmn_template
                     ERB.new bmn_template.text
                   else
                     ERB.new manager_notification_template
                   end
        
        message = template.result(binding)

        Notifier.delay.notify_manager(notification_email, 
          BookingDataSystem.r18n.t.notifications.manager_email_subject.to_s, 
          message,
          self.id)

      end

    end  
    
    #
    # Notifies by email the customer the booking request
    #
    # The email address is retrieved from the booking
    #
    # It allows to define a custom template naming it as booking_customer_req_notification
    #
    def notify_request_to_customer

      unless customer_email.empty?

        p "Entro"

        bcn_template = ContentManagerSystem::Template.first(:name => "booking_customer_req_notification_#{customer_language}") ||
                       ContentManagerSystem::Template.first(:name => 'booking_customer_req_notification')
        
        if bcn_template
          template = ERB.new bcn_template.text
        else
          template = ERB.new customer_notification_request_template
        end

        message = template.result(binding)

        Notifier.delay.notify_request_to_customer(self.customer_email, 
          BookingDataSystem.r18n.t.notifications.customer_req_email_subject.to_s, 
          message, 
          self.id)

      end

    end

    #
    # Notifies by email the customer the booking confirmation
    # 
    # The email address is retrieved from the booking
    #
    # It allows to define a custom template naming it as booking_customer_notification
    # 
    #
    def notify_customer

      unless customer_email.empty?

        bcn_template = ContentManagerSystem::Template.first(:name => "booking_customer_notification_#{customer_language}") ||
                       ContentManagerSystem::Template.first(:name => 'booking_customer_notification')
        
        if bcn_template
          template = ERB.new bcn_template.text
        else
          template = ERB.new customer_notification_template
        end

        message = template.result(binding)

        Notifier.delay.notify_customer(self.customer_email, 
          BookingDataSystem.r18n.t.notifications.customer_email_subject.to_s, 
          message, 
          self.id)

      end

    end

    private

    #
    # Gets the default template used to notify the booking manager
    #
    def manager_notification_template

      file = File.expand_path(File.join(File.dirname(__FILE__), "..", 
          "templates", "manager_notification_template.erb"))

      File.read(file)

    end
     
    #
    # Gets the default template used to notify the customer
    #
    def customer_notification_template

       file = File.expand_path(File.join(File.dirname(__FILE__), "..", 
          "templates", "customer_notification_template.erb"))

       File.read(file)

    end    

    #
    # Gets the default template used to notify the customer
    #
    def customer_notification_request_template

       file = File.expand_path(File.join(File.dirname(__FILE__), "..", 
          "templates", "customer_notification_template.erb"))

       File.read(file)

    end   

  
  end

end