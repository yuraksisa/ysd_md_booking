module BookingDataSystem

  module BookingNotifications
    
    # Notifies a new booking
    # 
    def notify_new_booking
    
      file = File.expand_path(File.join(File.dirname(__FILE__), "..", 
        "templates", "notificacion#{self.class.name.split('::').last}.erb"))
          
      template = ERB.new File.read(file)
      message = template.result binding
      
      Pony.mail( :subject => 'Solicitud de reserva', :body => message )
    
    end  
  
  end

end