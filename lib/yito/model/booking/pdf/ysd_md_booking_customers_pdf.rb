require 'prawn' unless defined?Prawn
require 'prawn/table' unless defined?Prawn::Table
module Yito
  module Model
    module Booking
      module Pdf
        #
        # Customers report
        #
        class Customers

          def build

            item_count, reservations = BookingDataSystem::Booking.customer_search(nil,{})


            pdf = Prawn::Document.new(:page_layout => :landscape) 
            font_file = File.expand_path(File.join(File.dirname(__FILE__), "../../../../..", 
            "fonts", "DejaVuSans.ttf"))
            pdf.font font_file


            pdf.text "Clientes", inline_format: true, size: 18
            pdf.move_down 20

            table_data = []
            header = ["Cliente", "Teléfono", "Email"]
            table_data << header

            reservations.each do |booking|
              data = []
              data << "#{booking.customer_surname}, #{booking.customer_name}"
              data << booking.customer_phone
              data << booking.customer_email
              table_data << data                                 
            end

            pdf.table(table_data, width: pdf.bounds.width) do |t|
              t.column(0).style(size: 8)	
              t.column(1).style(size: 8)
              t.column(2).style(size: 8)
            end   

            return pdf
            
          end

        end
      end
    end
  end
end