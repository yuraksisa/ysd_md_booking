require 'prawn' unless defined?Prawn
require 'prawn/table' unless defined?Prawn::Table
module Yito
  module Model
    module Booking
      module Pdf
        class Charges

          attr_reader :date_from, :date_to

          def initialize(date_from, date_to)
            @date_from = date_from
            @date_to = date_to
          end

          def build
            charges = BookingDataSystem::Booking.charges(date_from, date_to)

            pdf = Prawn::Document.new
            font_file = File.expand_path(File.join(File.dirname(__FILE__), "../../../../..", 
            "fonts", "DejaVuSans.ttf"))
            pdf.font font_file
                        
            pdf.text "Cobros", inline_format: true, size: 18
            pdf.move_down 10

            if charges.size == 0
              pdf.text "No hay cobros"
            else
              
              last_month = nil
              year = nil
              total = 0
              month_charges = []
              subtotals = {}

              charges.each do |charge|
                year = charge.date.year
                if last_month != charge.date.month
                  unless last_month.nil?
                    if month_charges.size > 0
                      pdf.move_down 20
                      pdf.text "#{BookingDataSystem.r18n.t.months[last_month]} #{year}"
                      pdf.move_down 10
                      build_table(month_charges, subtotals, total, pdf)
                    end
                    month_charges.clear
                    total = 0
                    subtotals.clear
                  end
                end
                month_charges << charge
                last_month = charge.date.month
                total += charge.amount
                subtotals.has_key?(charge.payment_method_id) ? subtotals[charge.payment_method_id] += charge.amount : subtotals[charge.payment_method_id] = charge.amount
              end

              if month_charges.size > 0
              	pdf.move_down 20
                pdf.text "#{BookingDataSystem.r18n.t.months[last_month]} #{year}"
                pdf.move_down 10
                build_table(month_charges, subtotals, total, pdf)
              end	

            end
            
            return pdf
          end

          private

          def build_table(charges, subtotals, total, pdf)
            
            table_data = []
            
            header = ["Fecha"]
            header << "Forma de pago"
            header << "Importe"
            header << "Origen"
            header << "Cliente"
            header << "NIF/CIF/VAT#"
            table_data << header

            charges.each do |charge|
              data = [charge.date.strftime('%Y-%m-%d %H:%M:%S'),
              	      charge.payment_method_id,
              	      "%.2f" % charge.amount,
              	      charge.source,
              	      "#{charge.customer_name} #{charge.customer_surname}",
                      charge.customer_document_id
                      ]              
              table_data << data                                 
            end
            subtotals.each do |payment_method_id, subtotal|
              data = ['',
                      "Total #{payment_method_id}",
                      "%.2f" % subtotal,
                      '',
                      '',
                      ''
                      ]              
              table_data << data  
            end  

            table_data << ['','TOTAL',"%.2f" % total, '', '', '']

            pdf.table(table_data, width: pdf.bounds.width) do |t|
              t.column(0).style(size: 8)	
              t.column(1).style(size: 8)
              t.column(2).style(:align => :right,size: 8)
              t.column(3).style(size: 8)
              t.column(4).style(size: 8)
              t.column(5).style(size: 8) 
            end   

          end	

        end
      end
    end
  end
end