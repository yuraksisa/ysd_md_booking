require 'ysd_service_postal' unless defined?ServicePostal

module BookingDataSystem

  module BookingNotifications
    
    #
    # Notifies that a new booking have been received
    # 
    def notify_new_booking
    
      if notification_email = SystemConfiguration::Variable.get_value('booking.notification_email')

        file = File.expand_path(File.join(File.dirname(__FILE__), "..", 
          "templates", "notificacion#{self.class.name.split('::').last}.erb"))
          
        template = ERB.new File.read(file)
        message = template.result binding
      
        PostalService.post(
          :to => notification_email,
          :subject => 'Solicitud de reserva',
          :body => message)
      
      end

    end  
  
  end

end