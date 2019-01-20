require 'prawn' unless defined?Prawn
require 'prawn/qrcode' unless defined?Prawn::QRCode
module Yito
  module Model
    module Booking
      module Pdf
        #
        # See https://es.qr-code-generator.com/#text
        # See https://github.com/jabbrwcky/prawn-qrcode
        # See https://github.com/whomwah/rqrcode
        #
        class QRcode

          attr_reader :booking

          def initialize(booking, company)
            @booking = booking
            @company = company
          end	

          def build

            pdf = Prawn::Document.new

            font_file = File.expand_path(File.join(File.dirname(__FILE__), "../../..", "fonts", "DejaVuSans.ttf"))
            font_file_bold = File.expand_path(File.join(File.dirname(__FILE__), "../../..", "fonts", "DejaVuSans-Bold.ttf"))
            pdf.font_families.update({'DejaVuSans' => { :normal => font_file, :bold => font_file_bold}})
            
            # -- First copy

            pdf.stroke_color "000000"
            pdf.fill_color "eeeeee"
            pdf.fill_rectangle [5, 725], 540, 20
            pdf.fill_color "000000"
            pdf.text "<b>ESTE VEHÍCULO ESTÁ DESTINADO AL ALQUILER SIN CONDUCTOR</b>", inline_format: true, align: :center, size: 12
            pdf.move_down 30

            y_position = pdf.cursor
            pdf.bounding_box([30, y_position], :width => 190, :height => 140) do
              pdf.move_down 5
              pdf.text "EMPRESA ALQUILADORA", size: 10
              pdf.text "<b>#{@company[:name]}</b>", inline_format: true, size:12
              pdf.move_down 10
              pdf.text "CONTRATO", inline_format: true, size:10
              pdf.text "<b>#{@booking.id}</b>",inline_format: true, size: 10
              pdf.move_down 10
              pdf.text "MATRICULA", inline_format: true, size:10
              pdf.text "<b>#{(booking.booking_lines and booking.booking_lines.size > 0 and booking.booking_lines.first.booking_line_resources and booking.booking_lines.first.booking_line_resources.size > 0 and booking.booking_lines.first.booking_line_resources.first) ? booking.booking_lines.first.booking_line_resources.first.booking_item_stock_plate : ''}</b>", inline_format: true, size:10                
              pdf.move_down 10
              pdf.text "PERÍODO DE ALQUILER", inline_format: true, size:10
              pdf.text "<b>De #{@booking.date_from.strftime('%d/%m/%Y')} #{@booking.time_from} a #{@booking.date_to.strftime('%d/%m/%Y')} #{@booking.time_to}", inline_format: true, size:10
            end

            qr_code_text = <<-QRCODE
EMPRESA ALQUILADORA
#{@company[:name]}
CONTRATO
#{@booking.id}
MATRICULA
#{(booking.booking_lines and booking.booking_lines.size > 0 and booking.booking_lines.first.booking_line_resources and booking.booking_lines.first.booking_line_resources.size > 0 and booking.booking_lines.first.booking_line_resources.first) ? booking.booking_lines.first.booking_line_resources.first.booking_item_stock_plate : ''}
PERÍODO DE ALQUILER
De #{@booking.date_from.strftime('%d/%m/%Y')} #{@booking.time_from} a #{@booking.date_to.strftime('%d/%m/%Y')} #{@booking.time_to}
            QRCODE

            pdf.bounding_box([230, y_position], width: 220, height: 140) do
              pdf.print_qr_code(qr_code_text, stroke: false, level: :q, dot: 2.2)
            end

            y_position = pdf.cursor

            pdf.bounding_box([30, y_position], width: 400, height: 30) do
              pdf.text "Por favor ponga este documento en un lugar visible sobre el salpicadero. Recuerde que este documento no le exime pago por estacionamiento", inline_format: true, size: 6
              pdf.text "Please, put this document on a visible location on top of the dashboard. Remember that this document does not avoid the corresponding parking's fee.", inline_format: true, size: 6
            end

            # -- Second copy


            pdf.move_down 50

            pdf.stroke_color "000000"
            pdf.fill_color "eeeeee"
            pdf.fill_rectangle [5, 460], 540, 20
            pdf.fill_color "000000"
            pdf.text "<b>ESTE VEHÍCULO ESTÁ DESTINADO AL ALQUILER SIN CONDUCTOR</b>", inline_format: true, align: :center, size: 12
            pdf.move_down 30

            y_position = pdf.cursor

            pdf.bounding_box([30, y_position], :width => 190, :height => 140) do
              pdf.move_down 5
              pdf.text "EMPRESA ALQUILADORA", size: 10
              pdf.text "<b>#{@company[:name]}</b>", inline_format: true, size:12
              pdf.move_down 10
              pdf.text "CONTRATO", inline_format: true, size:10
              pdf.text "<b>#{@booking.id}</b>",inline_format: true, size: 10
              pdf.move_down 10
              pdf.text "MATRICULA", inline_format: true, size:10
              pdf.text "<b>#{(booking.booking_lines and booking.booking_lines.size > 0 and booking.booking_lines.first.booking_line_resources and booking.booking_lines.first.booking_line_resources.size > 0 and booking.booking_lines.first.booking_line_resources.first) ? booking.booking_lines.first.booking_line_resources.first.booking_item_stock_plate : ''}</b>", inline_format: true, size:10                
              pdf.move_down 10
              pdf.text "PERÍODO DE ALQUILER", inline_format: true, size:10
              pdf.text "<b>De #{@booking.date_from.strftime('%d/%m/%Y')} #{@booking.time_from} a #{@booking.date_to.strftime('%d/%m/%Y')} #{@booking.time_to}", inline_format: true, size:10
            end

            pdf.bounding_box([230, y_position], width: 220, height: 140) do
              pdf.print_qr_code(qr_code_text, stroke: false, level: :q, dot: 2.2)
            end

            y_position = pdf.cursor

            pdf.bounding_box([30, y_position], width: 400, height: 30) do
              pdf.text "Por favor ponga este documento en un lugar visible sobre el salpicadero. Recuerde que este documento no le exime pago por estacionamiento", inline_format: true, size: 6
              pdf.text "Please, put this document on a visible location on top of the dashboard. Remember that this document does not avoid the corresponding parking's fee.", inline_format: true, size: 6
            end            

            return pdf

          end

        end
      end
    end
  end
end