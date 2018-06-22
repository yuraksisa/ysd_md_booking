require 'prawn' unless defined?Prawn
require 'prawn/table' unless defined?Prawn::Table
module Yito
  module Model
    module Booking
      module Pdf
        class PickupReturn
 
          attr_reader :from, :to, :rental_location_code, :include_journal, :product_family, :multiple_locations

          def initialize(date_from, date_to, rental_location_code=nil, include_journal=false)
            @from = date_from.nil? ? DateTime.now : date_from
            @to = date_to.nil? ? DateTime.now : date_to
            @rental_location_code = rental_location_code
            @include_journal = include_journal
            @product_family = ::Yito::Model::Booking::ProductFamily.get(SystemConfiguration::Variable.get_value('booking.item_family'))
            @multiple_locations = SystemConfiguration::Variable.get_value('booking.multiple_rental_locations', 'false').to_bool
          end

          def build

            picked_up_bookings = BookingDataSystem::Booking.pickup_list(from, to, rental_location_code, include_journal).map { |item| OpenStruct.new(item) }
            returned_bookings = BookingDataSystem::Booking.return_list(from, to, rental_location_code, include_journal).map {|item| OpenStruct.new(item)}

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
            header << "Notas"
            header << "Cliente"
            header << "Vuelo" if product_family.flight
            header << "Pdte."
            header << "Oficina" if multiple_locations

            table_data = []
            table_data << header

            span_rows = []
            no_span_rows = [0]
            idx = 1

            colspan = 7
            colspan = colspan + 1 if product_family.pickup_return_place
            colspan = colspan + 1 if product_family.flight
            colspan = colspan + 1 if multiple_locations

            picked_up_bookings.each do |booking|
              date_from = booking.date_from.strftime('%d-%m-%Y')
              if product_family.time_to_from
                date_from << ' '
                date_from << booking.time_from
              end
              data = []
              if booking.id == '.'
                data << date_from
                data << {content: booking.product, colspan: colspan}
                span_rows << idx
              else
                data << date_from
                data << (booking.id == '.' ? '' : booking.days)
                data << (booking.id == '.' ? '' : booking.id)
                data << booking.pickup_place if product_family.pickup_return_place
                data << booking.product
                data << booking.extras
                data << "#{BookingDataSystem.r18n.t.booking_status[booking.status]} #{booking.notes}"
                data << "#{booking.customer} #{booking.customer_phone} #{booking.customer_mobile_phone} #{booking.customer_email}"
                data << booking.flight if product_family.flight
                data <<  (booking.id == '.' ? '' : "%.2f" % booking.total_pending)
                data << booking.rental_location_code if multiple_locations
                no_span_rows << idx
              end
              table_data << data
              idx = idx + 1
            end

            pdf.table(table_data, width: pdf.bounds.width) do |t|
              if no_span_rows.size > 0
                col = 0
                t.rows(no_span_rows).column(0).style(size: 8, width: 90)
                t.rows(no_span_rows).column(1).style(size: 8, width: 30)
                t.rows(no_span_rows).column(2).style(size: 8, width: 50)
                if product_family.pickup_return_place
                  t.rows(no_span_rows).column(3).style(size: 8) #
                  col = col + 1
                end
                t.rows(no_span_rows).column(3 + col).style(size: 8, width: 120)
                t.rows(no_span_rows).column(4 + col).style(size: 8)
                t.rows(no_span_rows).column(5 + col).style(size: 8, width: 100)
                t.rows(no_span_rows).column(6 + col).style(size: 8)
                if product_family.flight
                  t.rows(no_span_rows).column(7 + col).style(size: 8) #
                  col = col + 1
                end
                t.rows(no_span_rows).column(7 + col).style(:align => :right, size: 8, width: 60)
                if multiple_locations
                  t.rows(no_span_rows).column(8 + col).style(size: 8, width: 80) #
                  col = col + 1
                end
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
            header << "Notas"
            header << "Cliente"
            header << "Oficina" if multiple_locations

            table_data = []
            table_data << header

            span_rows = []
            no_span_rows = [0]
            idx = 1

            colspan = 5
            colspan = colspan + 1 if product_family.pickup_return_place
            colspan = colspan + 1 if multiple_locations

            returned_bookings.each do |booking|

              date_to = booking.date_to.strftime('%d-%m-%Y')
              if product_family.time_to_from
                date_to << ' '
                date_to << booking.time_to
              end

              data = []
              if booking.id == '.'
                data << date_to
                data << {content: booking.product, colspan: colspan}
                span_rows << idx
              else
                data << date_to
                data << booking.id
                data << booking.return_place if product_family.pickup_return_place
                data << booking.product
                data << booking.extras
                data << "#{BookingDataSystem.r18n.t.booking_status[booking.status]} #{booking.notes}"
                data << "#{booking.customer} #{booking.customer_phone} #{booking.customer_mobile_phone} #{booking.customer_email}"
                data << booking.rental_location_code if multiple_locations
                no_span_rows << idx
              end
              table_data << data
              idx = idx + 1
            end

            pdf.table(table_data, width: pdf.bounds.width) do |t|
              if no_span_rows.size > 0
                t.rows(no_span_rows).column(0).style(size: 8, width: 90)
                t.rows(no_span_rows).column(1).style(size: 8)
                col = 0
                if product_family.pickup_return_place
                  t.rows(no_span_rows).column(2).style(size: 8, width: 70)
                  col = 1
                end
                t.rows(no_span_rows).column(2 + col).style(size: 8)
                t.rows(no_span_rows).column(3 + col).style(size: 8)
                t.rows(no_span_rows).column(4 + col).style(size: 8)
                t.rows(no_span_rows).column(5 + col).style(size: 8, width: 100)
                if multiple_locations
                  t.rows(no_span_rows).columns(6 + col).style(size: 8)
                end
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