require 'prawn' unless defined?Prawn
require 'prawn/table' unless defined?Prawn::Table
module Yito
  module Model
    module Booking
      module Pdf
        class CustomerReservations

          attr_reader :date_from, :date_to, :booking_reservation_starts_with, :product_family

          def initialize(date_from, date_to)
            @date_from = date_from
            @date_to = date_to       
            @product_family = ::Yito::Model::Booking::ProductFamily.get(SystemConfiguration::Variable.get_value('booking.item_family'))
            @booking_reservation_starts_with = @product_family.frontend
          end

          def build

            condition = Conditions::JoinComparison.new('$and',
             [Conditions::Comparison.new(:status, '$ne', [:cancelled, :pending_confirmation]),
              Conditions::JoinComparison.new('$or', 
                [Conditions::JoinComparison.new('$and', 
                 [Conditions::Comparison.new(:date_from,'$lte', date_from),
                  Conditions::Comparison.new(:date_to,'$gte', date_from)
                  ]),
                Conditions::JoinComparison.new('$and',
                 [Conditions::Comparison.new(:date_from,'$lte', date_to),
                  Conditions::Comparison.new(:date_to,'$gte', date_to)
                  ]),
               Conditions::JoinComparison.new('$and',
                 [Conditions::Comparison.new(:date_from,'$lte', date_from),
                  Conditions::Comparison.new(:date_to,'$gte', date_to)
                  ]),
               Conditions::JoinComparison.new('$and',
                 [Conditions::Comparison.new(:date_from, '$gte', date_from),
                  Conditions::Comparison.new(:date_to, '$lte', date_to)])               
              ]
            ),
            ]
          )

            reservations = condition.build_datamapper(BookingDataSystem::Booking).all(
             :order => [:date_from, :time_from])

            pdf = Prawn::Document.new(:page_layout => :portrait)
            font_file = File.expand_path(File.join(File.dirname(__FILE__), "../../../../..", 
            "fonts", "DejaVuSans.ttf"))
            pdf.font font_file
                        
            pdf.text "Reservas", inline_format: true, size: 18
            pdf.move_down 10

            if reservations.size == 0
              pdf.text "No hay reservas"
            else
              
              last_month = nil
              year = nil
              month_reservations = []

              reservations.each do |reservation|
                year = reservation.date_from.year
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
              	
            end
            
            return pdf
          end

          private

          def build_table(reservations, pdf)
            
            table_data = []
            
            header = ["Entrega"]
            header << "Devolución"
            header << "Cliente"
            header << "Documento"
            table_data << header

            reservations.each do |booking|
              pickup_date_place = "#{booking.date_from.strftime('%d-%m-%Y')} #{product_family.time_to_from ? booking.time_from : ''} "
              return_date_place = "#{booking.date_to.strftime('%d-%m-%Y')} #{product_family.time_to_from ? booking.time_to : ''} "
              data = [pickup_date_place,
              	      return_date_place,
              	      "#{booking.driver_name} #{booking.driver_surname}",
              	      booking.driver_document_id
                      ]              
              table_data << data                                 
            end

            pdf.table(table_data, width: pdf.bounds.width) do |t|
              t.column(0).style(size: 8)	
              t.column(1).style(size: 8)
              t.column(2).style(size: 8)
              t.column(3).style(size: 8)
            end   

          end	

        end
      end
    end
  end
end