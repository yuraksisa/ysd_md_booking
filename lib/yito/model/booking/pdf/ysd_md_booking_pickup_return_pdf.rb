require 'prawn' unless defined?Prawn
require 'prawn/table' unless defined?Prawn::Table
module Yito
  module Model
    module Booking
      module Pdf
        class PickupReturn
 
          attr_reader :from, :to, :product_family

          def initialize(date_from, date_to)
            @from = date_from.nil? ? DateTime.now : date_from
            @to = date_to.nil? ? DateTime.now : date_to
            @product_family = ::Yito::Model::Booking::ProductFamily.get(SystemConfiguration::Variable.get_value('booking.item_family'))
          end

          def build

            picked_up_bookings = BookingDataSystem::Booking.all(
                                   :date_from.gte => from,
                                   :date_from.lte => to,
                                   :status => [:confirmed, :in_progress, :done],
                                   :order => [:date_from.asc, :time_from.asc])

            returned_bookings = BookingDataSystem::Booking.all(
                                   :date_to.gte => from,
                                   :date_to.lte => to,
                                   :status => [:confirmed, :in_progress, :done],
                                   :order => [:date_to.asc, :time_to.asc])

            pdf = Prawn::Document.new(:page_layout => :landscape)
            font_file = File.expand_path(File.join(File.dirname(__FILE__), "../../../../..", 
            "fonts", "DejaVuSans.ttf"))
            pdf.font font_file
            
            pdf.text "Entregas y recogidas del #{from.strftime('%d-%m-%Y')} al #{to.strftime('%d-%m-%Y')}", inline_format: true, size: 18
            pdf.move_down 20

            pdf.text "Entregas", inline_format: true, size: 16
            pdf.move_down 10
            if picked_up_bookings.size > 0
              pdf.text "Hay #{picked_up_bookings.size} entregas"
              pdf.move_down 10 
              pickup_table(picked_up_bookings, pdf) 
            else
              pdf.text "No hay entregas"
            end

            pdf.move_down 30
            pdf.text "Recogidas", inline_format: true, size: 16
            pdf.move_down 10
            if returned_bookings.size > 0
              pdf.text "Hay #{returned_bookings.size} recogidas"
              pdf.move_down 10             	
              return_table(returned_bookings, pdf) 
            else
              pdf.text "No hay recogidas"
            end

            return pdf

          end

          private 

          def pickup_table(picked_up_bookings, pdf)

            table_data = []
            header = ["Reserva"]
            header << "Fecha entrega" 
            header << "Lugar" if product_family.pickup_return_place 
            header << "Producto"
            header << "Cliente"
            header << "Teléfono" 
            header << "Email" 
            header << "Vuelo" if product_family.flight 
            header << "Pdte." 
            table_data << header

            picked_up_bookings.each do |booking|
              data = [booking.id,
                      "#{booking.date_from.strftime('%d-%m-%Y')} #{product_family.time_to_from ? booking.time_from : ''}"]
              data << booking.pickup_place if product_family.pickup_return_place
              stock = []
              booking.booking_lines.each do |booking_line|
                booking_line.booking_line_resources.each do |booking_line_resource|
                  stock << booking_line_resource.booking_item.reference
                end 
              end
              data << stock.join(', ')
              data << "#{booking.customer_surname}, #{booking.customer_name}"
              data << "#{booking.customer_phone} #{booking.customer_mobile_phone}"
              data << booking.customer_email
              data << "#{booking.flight_company} #{booking.flight_number} #{booking.flight_time}" if product_family.flight
              data << "%.2f" % booking.total_pending
              table_data << data                                 
            end

            pdf.table(table_data, width: pdf.bounds.width) do |t|
              t.column(0).style(size: 8)	
              t.column(1).style(size: 8)
              t.column(2).style(size: 8)
              t.column(3).style(size: 8)
              t.column(4).style(size: 8)              
              t.column(5).style(size: 8, width: 70)
              t.column(6).style(size: 8)
              t.column(7).style(size: 8)
              t.column(8).style(:align => :right, size: 8)
            end   

          end

          def return_table(returned_bookings, pdf)

            table_data = []
            header = ["Reserva"]
            header << "Fecha recogida" 
            header << "Lugar" if product_family.pickup_return_place 
            header << "Producto"
            header << "Cliente"
            header << "Teléfono" 
            header << "Email"
            table_data << header

            returned_bookings.each do |booking|
              data = [booking.id,
                      "#{booking.date_from.strftime('%d-%m-%Y')} #{product_family.time_to_from ? booking.time_from : ''}"]
              data << booking.pickup_place if product_family.pickup_return_place
              stock = []
              booking.booking_lines.each do |booking_line|
                booking_line.booking_line_resources.each do |booking_line_resource|
                  stock << booking_line_resource.booking_item.reference
                end 
              end
              data << stock.join(', ')
              data << "#{booking.customer_surname}, #{booking.customer_name}"
              data << "#{booking.customer_phone} #{booking.customer_mobile_phone}"
              data << booking.customer_email
              table_data << data                                 
            end

            pdf.table(table_data, width: pdf.bounds.width) do |t|
              t.column(0).style(size: 8)	
              t.column(1).style(size: 8)
              t.column(2).style(size: 8)
              t.column(3).style(size: 8)
              t.column(4).style(size: 8)              
              t.column(5).style(size: 8, width: 70)
              t.column(6).style(size: 8)
            end 

          end

        end
      end
    end
  end
end