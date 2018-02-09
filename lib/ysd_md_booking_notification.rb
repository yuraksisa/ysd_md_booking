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
    # Notify the manager that a new request is being paid
    #
    def self.notify_manager_pay_now(to, subject, message, booking_id)

       PostalService.post(build_message(message).merge(:to => to, :subject => subject))
       if (booking = BookingDataSystem::Booking.get(booking_id))
         booking.update(:manager_notification_p_n_sent => true)
       end

    end
    
    #
    # Notifies the manager that a request has been confirmed
    #
    def self.notify_manager_confirmation(to, subject, message, booking_id)
      PostalService.post(build_message(message).merge(:to => to, :subject => subject))
  
      if booking = BookingDataSystem::Booking.get(booking_id)
        booking.update(:manager_confirm_notification_sent => true)
      end

    end 
    
    #
    # Notifies the customer that a new request has been received
    #
    def self.notify_request_to_customer(to, subject, message, booking_id)

      message_and_settings = build_message(message).merge(:to => to, :subject => subject)

      # Get the settings from the sales channel
      if booking = BookingDataSystem::Booking.get(booking_id)
        unless booking.sales_channel_code.nil?
          if scb = ::Yito::Model::SalesChannel::SalesChannelBooking.first('sales_channel.code' => booking.sales_channel_code)
            scb_smtp_settings = scb.smtp_configuration
            message_and_settings.merge!(scb_smtp_settings) unless scb_smtp_settings.nil?
          end
        end
      end

      # Send the mail
      PostalService.post(message_and_settings)

      # Update the booking status
      if booking
        booking.update(:customer_req_notification_sent => true)
      end

    end
    
    #
    # Notifies the customer that a new request has been received (payment process)
    #
    def self.notify_request_to_customer_pay_now(to, subject, message, booking_id)

      message_and_settings = build_message(message).merge(:to => to, :subject => subject)

      # Get the settings from the sales channel
      if booking = BookingDataSystem::Booking.get(booking_id)
        unless booking.sales_channel_code.nil?
          if scb = ::Yito::Model::SalesChannel::SalesChannelBooking.first('sales_channel.code' => booking.sales_channel_code)
            scb_smtp_settings = scb.smtp_configuration
            message_and_settings.merge!(scb_smtp_settings) unless scb_smtp_settings.nil?
          end
        end
      end
      
      # Send the mail
      PostalService.post(message_and_settings)

      # Update the booking status
      if booking 
        booking.update(:customer_req_notification_p_sent => true)
      end      

    end

    #
    # Notifies the customer when the booking is confirmed 
    #
    def self.notify_customer(to, subject, message, booking_id)

      message_and_settings = build_message(message).merge(:to => to, :subject => subject)

      # Get the settings from the sales channel
      if booking = BookingDataSystem::Booking.get(booking_id)
        unless booking.sales_channel_code.nil?
          if scb = ::Yito::Model::SalesChannel::SalesChannelBooking.first('sales_channel.code' => booking.sales_channel_code)
            scb_smtp_settings = scb.smtp_configuration
            message_and_settings.merge!(scb_smtp_settings) unless scb_smtp_settings.nil?
          end
        end
      end      
      
      # Send the mail
      PostalService.post(message_and_settings)

      # Update the booking status
      if booking
        booking.update(:customer_notification_sent => true)
      end

    end

    #
    # Notifies the customer when the payment is enabled
    #
    def self.notify_customer_payment_enabled(to, subject, message, booking_id)

      message_and_settings = build_message(message).merge(:to => to, :subject => subject)

      # Get the settings from the sales channel
      if booking = BookingDataSystem::Booking.get(booking_id)
        unless booking.sales_channel_code.nil?
          if scb = ::Yito::Model::SalesChannel::SalesChannelBooking.first('sales_channel.code' => booking.sales_channel_code)
            scb_smtp_settings = scb.smtp_configuration
            message_and_settings.merge!(scb_smtp_settings) unless scb_smtp_settings.nil?
          end
        end
      end      
      
      # Send the mail
      PostalService.post(message_and_settings)

      # Update the booking status
      if booking
        booking.update(:customer_payment_enabled_sent => true)
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
  # Booking Notification default templates
  #
  module BookingNotificationTemplates

    #
    # Gets the default template used to notify the booking manager that an user is paying
    #
    def manager_notification_pay_now_template

      file = File.expand_path(File.join(File.dirname(__FILE__), "..", 
          "templates", "manager_notification_pay_now_template.erb"))

      File.read(file)

    end


    #
    # Gets the default template used to notify the booking manager
    #
    def manager_notification_template

      file = File.expand_path(File.join(File.dirname(__FILE__), "..", 
          "templates", "manager_notification_template.erb"))

      File.read(file)

    end

    #
    # Gets the default template used to notify the confirmation of a booking to the manager
    #
    def manager_confirm_notification_template

      file = File.expand_path(File.join(File.dirname(__FILE__), "..", 
          "templates", "manager_confirm_notification_template.erb"))

      File.read(file)

    end

    #
    # Gets the default template used to notify the customer
    #
    def customer_notification_booking_request_template

       file = File.expand_path(File.join(File.dirname(__FILE__), "..", 
          "templates", "customer_notification_booking_request_template.erb"))

       File.read(file)

    end 
     
    #
    # Gets the default template used to notify customer pay now
    #
    def customer_notification_request_pay_now_template

       file = File.expand_path(File.join(File.dirname(__FILE__), "..", 
          "templates", "customer_notification_pay_now_template.erb"))

       File.read(file)


    end

    #
    # Gets the default template used to notify the customer that the reservation is confirmed
    #
    def customer_notification_booking_confirmed_template

       file = File.expand_path(File.join(File.dirname(__FILE__), "..", 
          "templates", "customer_notification_booking_confirmed_template.erb"))

       File.read(file)

    end    

    #
    # Gets the default template used to notify the customer that the payment has been enabled
    #
    def customer_notification_payment_enabled_template

       file = File.expand_path(File.join(File.dirname(__FILE__), "..", 
          "templates", "customer_notification_payment_enabled_template.erb"))

       File.read(file)

    end

  end

  #
  # Send notifications to the booking manager and to the customer
  #
  #
  module BookingNotifications
    
    def self.included(model)
     
     if model.respond_to?(:property)
       model.property :customer_req_notification_sent, DataMapper::Property::Boolean, :field => 'customer_req_notification_sent', :default => false
       model.property :customer_req_notification_p_sent, DataMapper::Property::Boolean, :field => 'customer_req_notification_p_sent', :default => false
       model.property :customer_notification_sent, DataMapper::Property::Boolean, :field => 'customer_notification_sent'
       model.property :customer_payment_enabled_sent, DataMapper::Property::Boolean, :field => 'customer_payment_enabled_sent', :default => false
       model.property :manager_notification_sent, DataMapper::Property::Boolean, :field => 'manager_notification_sent'
       model.property :manager_notification_p_n_sent, DataMapper::Property::Boolean, :field => 'manager_notification_p_n_sent', :default => false
       model.property :manager_confirm_notification_sent, DataMapper::Property::Boolean, :field => 'manager_confirm_notification_sent', :default => false
     end

    end

    #
    # Notifies by email the booking manager that a new booking have been received
    # 
    # The manager address can be set up on booking.notification_email variable
    #
    # It allows to define a custom template naming it as booking_manager_notification
    # 
    def notify_manager(force_send=false)

      if force_send || send_notifications?
        if notification_email = SystemConfiguration::Variable.get_value('booking.notification_email')
          bmn_template = ContentManagerSystem::Template.first(:name => 'booking_manager_notification')

          template = if bmn_template
                     ERB.new bmn_template.text
                   else
                     ERB.new Booking.manager_notification_template
                   end
        
          message = template.result(binding)

          Notifier.delay.notify_manager(notification_email, 
            BookingDataSystem.r18n.t.notifications.manager_email_subject.to_s, 
            message,
            self.id)

        end
      end  

    end  

    #
    # Notifies by email the booking manager that a new booking have been received
    # 
    # The manager address can be set up on booking.notification_email variable
    #
    # It allows to define a custom template naming it as booking_manager_notification
    # 
    def notify_manager_pay_now(force_send=false)

      if force_send || send_notifications?
        if notification_email = SystemConfiguration::Variable.get_value('booking.notification_email')

          bmn_template = ContentManagerSystem::Template.first(:name => 'booking_manager_notification_pay_now')
          template = if bmn_template
                       ERB.new bmn_template.text
                     else
                       ERB.new Booking.manager_notification_pay_now_template
                     end
        
          message = template.result(binding)

          Notifier.delay.notify_manager_pay_now(notification_email, 
            BookingDataSystem.r18n.t.notifications.manager_paying_email_subject.to_s, 
            message,
            self.id)
        end
      end

    end
    
    #
    # Notifies by email the booking manager that a booking has been confirmed
    # 
    # The manager address can be set up on booking.notification_email variable
    #
    # It allows to define a custom template naming it as booking_manager_notification
    # 
    def notify_manager_confirmation(force_send=false)

      if force_send || send_notifications?
        if notification_email = SystemConfiguration::Variable.get_value('booking.notification_email')
          bmn_template = ContentManagerSystem::Template.first(:name => 'booking_confirmation_manager_notification')

          template = if bmn_template
                       ERB.new bmn_template.text
                     else
                       ERB.new Booking.manager_confirm_notification_template
                     end
        
          message = template.result(binding)

          Notifier.delay.notify_manager(notification_email, 
            BookingDataSystem.r18n.t.notifications.manager_confirmation_email_subject.to_s, 
            message,
            self.id)
        end
      end

    end  

    #
    # Notifies by email the customer the booking request
    #
    # The email address is retrieved from the booking
    #
    # It allows to define a custom template naming it as booking_customer_req_notification
    #
    def notify_request_to_customer(force_send=false)

      if force_send || send_notifications?
        unless customer_email.empty?

          # Try to get sales channel template
          bcn_template = nil
          unless self.sales_channel_code.nil?
            if scb = ::Yito::Model::SalesChannel::SalesChannelBooking.first('sales_channel.code' => self.sales_channel_code)
              bcn_template = scb.customer_notification_booking_request_template
            end
          end

          # Try to get the default custom template
          bcn_template = ContentManagerSystem::Template.first(:name => 'booking_customer_req_notification') if bcn_template.nil?
        
          if bcn_template
            template = ERB.new bcn_template.translate(customer_language).text
          else
            template = ERB.new Booking.customer_notification_booking_request_template
          end

          message = template.result(binding)

          Notifier.delay.notify_request_to_customer(self.customer_email, 
            BookingDataSystem.r18n.t.notifications.customer_req_email_subject.to_s, 
            message, 
            self.id)
        end
      end

    end

    #
    # Notifies by email the customer the booking request
    #
    # The email address is retrieved from the booking
    #
    # It allows to define a custom template naming it as booking_customer_req_notification
    #
    def notify_request_to_customer_pay_now(force_send=false)

      if force_send || send_notifications?
        unless customer_email.empty?

          # Try to get sales channel template
          bcn_template = nil
          unless self.sales_channel_code.nil?
            if scb = ::Yito::Model::SalesChannel::SalesChannelBooking.first('sales_channel.code' => self.sales_channel_code)
              bcn_template = scb.customer_notification_request_pay_now_template
            end
          end

          # Try to get the default custom template
          bcn_template = ContentManagerSystem::Template.first(:name => 'booking_customer_req_pay_now_notification') if bcn_template.nil?
        
          if bcn_template
            template = ERB.new bcn_template.translate(customer_language).text
          else
            template = ERB.new Booking.customer_notification_request_pay_now_template
          end

          message = template.result(binding)

          Notifier.delay.notify_request_to_customer_pay_now(self.customer_email, 
            BookingDataSystem.r18n.t.notifications.customer_req_email_subject.to_s, 
            message, 
            self.id)
        end
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
    def notify_customer(force_send=false)

      if force_send || send_notifications?
        unless customer_email.empty?

          # Try to get sales channel template
          bcn_template = nil
          unless self.sales_channel_code.nil?
            if scb = ::Yito::Model::SalesChannel::SalesChannelBooking.first('sales_channel.code' => self.sales_channel_code)
              bcn_template = scb.customer_notification_booking_confirmed_template
            end
          end

          # Try to get the default custom template
          bcn_template = ContentManagerSystem::Template.first(:name => 'booking_customer_notification') if bcn_template.nil?
        
          if bcn_template
            template = ERB.new bcn_template.translate(customer_language).text
          else
            template = ERB.new Booking.customer_notification_booking_confirmed_template
          end

          message = template.result(binding)

          Notifier.delay.notify_customer(self.customer_email, 
            BookingDataSystem.r18n.t.notifications.customer_email_subject.to_s, 
            message, 
            self.id)
        end
      end

    end

    #
    # Notifies by email the customer that the payment has been enabled for the booking
    #
    def notify_customer_payment_enabled(force_send=false)

      if force_send || send_notifications?
        unless customer_email.empty?

          # Try to get sales channel template
          bcn_template = nil
          unless self.sales_channel_code.nil?
            if scb = ::Yito::Model::SalesChannel::SalesChannelBooking.first('sales_channel.code' => self.sales_channel_code)
              bcn_template = scb.customer_notification_payment_enabled_template
            end
          end

          # Try to get the default custom template
          bcn_template = ContentManagerSystem::Template.first(:name => 'booking_customer_notification_payment_enabled') if bcn_template.nil?
        
          if bcn_template
            template = ERB.new bcn_template.translate(customer_language).text
          else
            template = ERB.new Booking.customer_notification_booking_confirmed_template
          end

          message = template.result(binding)

          Notifier.delay.notify_customer_payment_enabled(self.customer_email, 
            BookingDataSystem.r18n.t.notifications.customer_payment_enabled_subject.to_s, 
            message, 
            self.id)
        end  
      end


    end

    #
    # Check if the notifications should be send
    #
    def send_notifications?

      if created_by_manager
        notify = SystemConfiguration::Variable.get_value('booking.send_notifications_backoffice_reservations', 'false').to_bool
      else
        notify = SystemConfiguration::Variable.get_value('booking.send_notifications', 'true').to_bool
      end

    end
  
  end

end