require 'prawn' unless defined?Prawn
require 'prawn/table' unless defined?Prawn::Table
module Yito
  module Model
    module Booking
      module Pdf
        class PickupReturn
 
          attr_reader :from, :to, :include_journal, :product_family

          def initialize(date_from, date_to, include_journal=false)
            @from = date_from.nil? ? DateTime.now : date_from
            @to = date_to.nil? ? DateTime.now : date_to
            @include_journal = include_journal
            @product_family = ::Yito::Model::Booking::ProductFamily.get(SystemConfiguration::Variable.get_value('booking.item_family'))
          end

          def build

            picked_up_bookings = BookingDataSystem::Booking.pickup_list(from, to, include_journal).map { |item| OpenStruct.new(item) }
            returned_bookings = BookingDataSystem::Booking.return_list(from, to, include_journal).map {|item| OpenStruct.new(item)}

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

            header = []
            header << "Fecha entrega"
            header << "Días"
            header << "Reserva"
            header << "Lugar" if product_family.pickup_return_place
            header << "Producto(s)"
            header << "Extra(s)"
            header << "Cliente"
            header << "Notas"
            header << "Vuelo" if product_family.flight
            header << "Pdte."

            table_data = []
            table_data << header

            span_rows = []
            no_span_rows = [0]
            idx = 1

            picked_up_bookings.each do |booking|
              date_from = booking.date_from.strftime('%d-%m-%Y')
              if product_family.time_to_from
                date_from << ' '
                date_from << booking.time_from
              end
              data = []
              if booking.id == '.'
                data << date_from
                data << {content: booking.product, colspan: 9}
                span_rows << idx
              else
                data << date_from
                data << (booking.id == '.' ? '' : booking.days)
                data << (booking.id == '.' ? '' : booking.id)
                data << booking.pickup_place if product_family.pickup_return_place
                data << booking.product
                data << booking.extras
                data << "#{booking.customer} #{booking.customer_phone} #{booking.customer_mobile_phone} #{booking.customer_email}"
                data << booking.notes
                data << booking.flight if product_family.flight
                data <<  (booking.id == '.' ? '' : "%.2f" % booking.total_pending)
                no_span_rows << idx
              end
              table_data << data
              idx = idx + 1
            end

            pdf.table(table_data, width: pdf.bounds.width) do |t|
              if no_span_rows.size > 0
                t.rows(no_span_rows).column(0).style(size: 8, width: 90)
                t.rows(no_span_rows).column(1).style(size: 8, width: 30)
                t.rows(no_span_rows).column(2).style(size: 8, width: 50)
                t.rows(no_span_rows).column(3).style(size: 8)
                t.rows(no_span_rows).column(4).style(size: 8, width: 120)
                t.rows(no_span_rows).column(5).style(size: 8)
                t.rows(no_span_rows).column(6).style(size: 8, width: 100)
                t.rows(no_span_rows).column(7).style(size: 8)
                t.rows(no_span_rows).column(8).style(size: 8)
                t.rows(no_span_rows).column(9).style(:align => :right, size: 8, width: 60)
              end
              if span_rows.size > 0
                t.rows(span_rows).column(0).style(size: 8)
                t.rows(span_rows).column(1).style(size: 8)
              end
            end   

          end

          def return_table(returned_bookings, pdf)

            header = []
            header << "Fecha recogida"
            header << "Reserva"
            header << "Lugar" if product_family.pickup_return_place
            header << "Producto"
            header << "Extras"
            header << "Cliente"
            header << "Teléfono" 
            header << "Email"

            table_data = []
            table_data << header

            span_rows = []
            no_span_rows = [0]
            idx = 1

            returned_bookings.each do |booking|

              date_to = booking.date_to.strftime('%d-%m-%Y')
              if product_family.time_to_from
                date_to << ' '
                date_to << booking.time_to
              end

              data = []
              if booking.id == '.'
                data << date_to
                data << {content: booking.product, colspan: 7}
                span_rows << idx
              else
                data << date_to
                data << booking.id
                data << booking.return_place if product_family.pickup_return_place
                data << booking.product
                data << booking.extras
                data << booking.customer
                data << "#{booking.customer_phone} #{booking.customer_mobile_phone}"
                data << booking.customer_email
                no_span_rows << idx
              end
              table_data << data
              idx = idx + 1
            end

            pdf.table(table_data, width: pdf.bounds.width) do |t|
              if no_span_rows.size > 0
                t.rows(no_span_rows).column(0).style(size: 8, width: 90)
                t.rows(no_span_rows).column(1).style(size: 8)
                t.rows(no_span_rows).column(2).style(size: 8, width: 70)
                t.rows(no_span_rows).column(3).style(size: 8)
                t.rows(no_span_rows).column(4).style(size: 8)
                t.rows(no_span_rows).column(5).style(size: 8)
                t.rows(no_span_rows).column(6).style(size: 8, width: 70)
                t.rows(no_span_rows).column(7).style(size: 8)
              end
              if span_rows.size > 0
                t.rows(span_rows).column(0).style(size: 8)
                t.rows(span_rows).column(1).style(size: 8)
              end  
            end 

          end

        end
      end
    end
  end
end