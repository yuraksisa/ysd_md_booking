require 'prawn' unless defined?Prawn
require 'prawn/table' unless defined?Prawn::Table
module Yito
  module Model
    module Booking
      module Pdf
        class Reservations

          attr_reader :year, :booking_reservation_starts_with, :product_family

          def initialize(year)
            @year = year
            @booking_reservation_starts_with =
              SystemConfiguration::Variable.get_value('booking.reservation_starts_with', :dates).to_sym         
            @product_family = ::Yito::Model::Booking::ProductFamily.get(SystemConfiguration::Variable.get_value('booking.item_family'))
          end

          def build
            date_from = Date.civil(year,1,1)
            date_to = Date.civil(year,12,31)
            reservations = BookingDataSystem::Booking.all(
               :conditions => {:date_from.gte => date_from,
                               :date_to.lte => date_to,
                               :status.not => :cancelled},
               :order => [:date_from, :time_from])

            pdf = Prawn::Document.new(:page_layout => :landscape)
            font_file = File.expand_path(File.join(File.dirname(__FILE__), "../../../../..", 
            "fonts", "DejaVuSans.ttf"))
            pdf.font font_file
                        
            pdf.text "Reservas", inline_format: true, size: 18
            pdf.move_down 10

            if reservations.size == 0
              pdf.text "No hay entregas"
            else
              
              last_month = nil
              month_reservations = []

              reservations.each do |reservation|
                if last_month != reservation.date_from.month
                  unless last_month.nil?
                    if month_reservations.size > 0
                      pdf.move_down 20
                      pdf.text "#{BookingDataSystem.r18n.t.months[last_month]} #{year}"
                      pdf.move_down 10
                      build_table(month_reservations, pdf)
                    end
                    month_reservations.clear
                  end
                end
                month_reservations << reservation
                last_month = reservation.date_from.month
              end

              if month_reservations.size > 0
              	pdf.move_down 20
                pdf.text "#{BookingDataSystem.r18n.t.months[last_month]} #{year}"
                pdf.move_down 10
                build_table(month_reservations, pdf)
              end	
              	
              #build_table(reservations, pdf) 

            end
            
            return pdf
          end

          private

          def build_table(reservations, pdf)
            
            table_data = []
            
            header = ["Entrega"]
            header << "Devolución"
            header << "Reserva"
            header << "Cliente"
            header << "Teléfono"
            header << "Email"
            header << "Estado"
            header << "Prod."
            header << "Total"
            header << "Pagado"
            header << "Pdte." 
            table_data << header

            reservations.each do |booking|
              pickup_date_place = "#{booking.date_from.strftime('%d-%m-%Y')} #{product_family.time_to_from ? booking.time_from : ''} "
              pickup_date_place << "#{booking.pickup_place}" if product_family.pickup_return_place
              return_date_place = "#{booking.date_to.strftime('%d-%m-%Y')} #{product_family.time_to_from ? booking.time_to : ''} "
              return_date_place << "#{booking.return_place}" if product_family.pickup_return_place
              products = []
              booking.booking_lines.each do |booking_line|
              	quantity = booking_reservation_starts_with == :shopcart ? "#{booking_line.quantity}" : ''
                products << "#{booking_line.item_id} #{quantity}"
              end
              data = [pickup_date_place,
              	      return_date_place,
              	      booking.id,
              	      "#{booking.customer_surname}, #{booking.customer_name}",
              	      "#{booking.customer_phone} #{booking.customer_mobile_phone}",
              	      booking.customer_email,
              	      BookingDataSystem.r18n.t.booking_status[booking.status],
              	      products.join(' '),
              	      "%.2f" % booking.total_cost,
              	      "%.2f" % booking.total_paid,
              	      "%.2f" % booking.total_pending
                      ]              
              table_data << data                                 
            end

            pdf.table(table_data, width: pdf.bounds.width) do |t|
              t.column(0).style(size: 8, width: 80)	
              t.column(1).style(size: 8, width: 80)
              t.column(2).style(size: 8, width: 50)
              t.column(3).style(size: 8, width: 90)
              t.column(4).style(size: 8, width: 70)              
              t.column(5).style(size: 8, width: 100)
              t.column(6).style(size: 8, width: 60)
              t.column(7).style(size: 8, width: 40)
              t.column(8).style(:align => :right, size: 8, width: 50)
              t.column(9).style(:align => :right, size: 8, width: 50)
              t.column(10).style(:align => :right, size: 8, width: 50)
            end   

          end	

        end
      end
    end
  end
end