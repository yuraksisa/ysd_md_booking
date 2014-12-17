module Yito
  module Model
    module Booking
      module Templates
      	def self.contract
          file = File.expand_path(File.join(File.dirname(__FILE__), "../../../..", 
            "templates", "contract.erb"))
          File.read(file)      	  
      	end
      	def self.summary_message
          file = File.expand_path(File.join(File.dirname(__FILE__), "../../../..", 
            "templates", "summary_message.erb"))
          File.read(file)    
      	end
      end
    end
  end
end