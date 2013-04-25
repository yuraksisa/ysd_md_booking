require 'ysd_service_postal' unless defined?ServicePostal
require 'ysd_md_cms' unless defined?ContentManagerSystem::Template
require 'delayed_job'

module BookingDataSystem
  
  #
  # Send notifications to the booking manager and to the customer
  #
  #
  module BookingNotifications
    
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

        PostalService.delay.post(
          :to => notification_email,
          :subject => 'Solicitud de reserva',
          :body => message )
      
      end

    end  
    
    #
    # Notifies by email the customer the booking confirmation
    # 
    # The email address is retrieved from the booking
    #
    # It allows to define a custom template naming it as booking_manager_notification
    # 
    #
    def notify_customer

      unless customer_email.empty?

        bcn_template = ContentManagerSystem::Template.first(:name => 'booking_customer_notification')
        
        if bcn_template
          template = ERB.new bcn_template.text
        else
          template = ERB.new customer_notification_template
        end

        message = template.result(binding)

        PostalService.delay.post(
          :to => customer_email,
          :subject => 'Su reserva',
          :body => message)

      end

    end

  
  end

end