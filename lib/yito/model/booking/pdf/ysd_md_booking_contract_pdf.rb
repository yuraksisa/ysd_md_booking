require 'prawn' unless defined?Prawn
require 'prawn/table' unless defined?Prawn::Table
module Yito
  module Model
    module Booking
      module Pdf
        class Contract

          attr_reader :booking
          attr_reader :company
          attr_reader :product_family
          attr_reader :logo_path

          def initialize(booking, company, logo_path)
            @booking = booking
            @company = company
            @product_family = ::Yito::Model::Booking::ProductFamily.get(SystemConfiguration::Variable.get_value('booking.item_family'))
            @logo_path = logo_path
          end	

          def build

            pdf = Prawn::Document.new

            font_file = File.expand_path(File.join(File.dirname(__FILE__), "../../..", "fonts", "DejaVuSans.ttf"))
            font_file_bold = File.expand_path(File.join(File.dirname(__FILE__), "../../..", "fonts", "DejaVuSans-Bold.ttf"))
            pdf.font_families.update({'DejaVuSans' => { :normal => font_file, :bold => font_file_bold}})
            
            # Header =======================

            # ----- Logo -------------------

            logo = SystemConfiguration::Variable.get_value('invoices.customer_invoice_logo')
            root_path = SystemConfiguration::Variable.get_value('media.public_folder_root','')
            base_path = if root_path.empty?
                        "#{File.join(File.expand_path($0).gsub($0,''))}/public"                          
                        else
                          "#{root_path}/public"
                        end  
            unless logo.empty?
               id = logo.split('/').last
               photo = Media::Photo.get(id)
               logo_path = File.join(base_path, photo.photo_url_full) 
               pdf.image logo_path, width: 300, at: [0, 730]
            end

            # ---- Company information -----
            pdf.text_box "<b>#{company[:name]}</b>", inline_format: true, at: [400, 735], size: 10
            pdf.draw_text "#{company[:address_1]}", at: [400,715], size: 10
            pdf.draw_text "#{company[:zip]} - #{company[:city]} (#{company[:country]})", at:[400, 700], size: 10
            pdf.draw_text "#{company[:email]}", at: [400, 685], size: 10
            pdf.draw_text "#{company[:phone_number]}", at: [400, 670], size: 10
            pdf.draw_text "#{company[:document_id]}", at: [400, 655], size: 10

            # Contract information =========
            pdf.move_down 80
            pdf.text "<b>CONTRATO DE ALQUILER / RENTAL AGREEMENT</b>", inline_format: true, size: 14
            pdf.move_down 10

            # General border
            pdf.stroke_color "000000"
            pdf.stroke_rectangle [0, 620], 550, 540
          
            # Vehicle data =================

            pdf.stroke_color "000000"
            pdf.stroke { pdf.line [0,560], [550, 560]} # Horizontal line total
            pdf.stroke { pdf.line [335, 620], [335, 560] } # Vertical line Vehicle Data / Pickup-return
            pdf.stroke { pdf.line [475, 620], [475, 560] } # Vertical line Pickup-return / Booking id

            y_position = pdf.cursor
            pdf.bounding_box([5, y_position], :width => 175, :height => 60) do
              pdf.fill_color "eeeeee"
              pdf.fill_rectangle [-4, 66], 175, 18
              pdf.fill_color "000000"
              pdf.text "<b>DATOS DEL VEHÍCULO</b>", inline_format: true, size: 10, align: :center
              pdf.move_down 2
              pdf.text "<b>Matrícula:</b> #{(booking.booking_lines and booking.booking_lines.size > 0 and booking.booking_lines.first.booking_line_resources and booking.booking_lines.first.booking_line_resources.size > 0 and booking.booking_lines.first.booking_line_resources.first) ? booking.booking_lines.first.booking_line_resources.first.booking_item_stock_plate : ''}", inline_format: true, size:10
              pdf.text "<b>Marca y modelo:</b> #{(booking.booking_lines and booking.booking_lines.size > 0 and booking.booking_lines.first.booking_line_resources and booking.booking_lines.first.booking_line_resources.size > 0 and booking.booking_lines.first.booking_line_resources.first) ? booking.booking_lines.first.booking_line_resources.first.booking_item_stock_model : ''} ", inline_format: true, size:10
              pdf.text "<b>Color:</b> #{(booking.booking_lines and booking.booking_lines.size > 0 and booking.booking_lines.first.booking_line_resources and booking.booking_lines.first.booking_line_resources.size > 0 and booking.booking_lines.first.booking_line_resources.first) ? booking.booking_lines.first.booking_line_resources.first.booking_item_characteristic_4 : ''}", inline_format: true, size:10
            end  

            pdf.bounding_box([180, y_position], :width => 160, :height => 60) do
              pdf.text "", size: 12
              pdf.text "<b>Grupo:</b> #{(booking.booking_lines and booking.booking_lines.size > 0) ? booking.booking_lines.first.item_id : ''}", inline_format: true, size:10
              pdf.text "<b>Combustible:</b> #{(booking.booking_lines and booking.booking_lines.size > 0 and booking.booking_lines.first.booking_line_resources and booking.booking_lines.first.booking_line_resources.size > 0 and booking.booking_lines.first.booking_line_resources.first) ? booking.booking_lines.first.booking_line_resources.first.booking_item_characteristic_1 : ''} ", inline_format: true, size:10
            end 

            pdf.bounding_box([340, y_position], :width => 140, :height => 60) do        
              pdf.text "<b>Salida-gas:</b> #{booking.pickup_fuel}", inline_format: true, size:10
              pdf.text "<b>Entrada-gas:</b> #{booking.return_fuel}", inline_format: true, size:10
              pdf.text "<b>Salida-km:</b> #{(booking.booking_lines and booking.booking_lines.size > 0 and booking.booking_lines.first.booking_line_resources and booking.booking_lines.first.booking_line_resources.size > 0 and booking.booking_lines.first.booking_line_resources.first) ? booking.booking_lines.first.booking_line_resources.first.km_miles_on_pickup : ''}", inline_format: true, size:10
              pdf.text "<b>Entrada-km:</b> #{(booking.booking_lines and booking.booking_lines.size > 0 and booking.booking_lines.first.booking_line_resources and booking.booking_lines.first.booking_line_resources.size > 0 and booking.booking_lines.first.booking_line_resources.first) ? booking.booking_lines.first.booking_line_resources.first.km_miles_on_return : ''} ", inline_format: true, size:10
            end 

            pdf.bounding_box([480, y_position], :width => 70, :height => 60) do
              pdf.move_down 35
              pdf.text "<b>#{booking.id}</b>", inline_format: true, size:12, align: :center
            end      

            # Column 1 ==============================

            # Column 1 separator
            pdf.stroke_color "000000"
            pdf.stroke { pdf.line [280, 560], [280, 80] }

            y_position = pdf.cursor
            pdf.bounding_box([5, y_position], :width => 275, :height => 60) do
              # Aditional Driver 
              pdf.fill_color "eeeeee"
              pdf.fill_rectangle [-4, 66], 278, 18
              pdf.fill_color "000000"
              pdf.text "<b>CONDUCTOR ADICIONAL</b>", inline_format: true, size: 10, align: :center
              pdf.move_down 5
              pdf.text "1- #{booking.additional_driver_1_name} #{booking.additional_driver_1_surname} <b>#{booking.additional_driver_1_driving_license_number}</b>", inline_format: true, size:10
              pdf.move_down 5
              pdf.text "2- #{booking.additional_driver_2_name} #{booking.additional_driver_2_surname} <b>#{booking.additional_driver_2_driving_license_number}</b>", inline_format: true, size:10
            end 

            pdf.bounding_box([5, y_position - 60], :width => 275, :height => 240) do
              # Vehicle status
              pdf.fill_color "eeeeee"
              pdf.fill_rectangle [-4, 246], 278, 18
              pdf.fill_color "000000"
              pdf.text "<b>ESTADO DEL VEHÍCULO</b>", inline_format: true, size: 10, align: :center
              damages_img_path = File.expand_path(File.join(File.dirname(__FILE__), "../../../../..", "img", "contract-vehicle-damages.jpg"))
              pdf.image damages_img_path, width: 270, at: [0, 220]
              pdf.move_down 190
              pdf.text "<b>(1)</b> Roce <b>(2)</b> Golpe <b>(3)</b> Arañazo <b>(4)</b> Quemado <b>(5)</b> Roto", inline_format: true, size: 10, align: :center
            end 

            # Pickup time / place
            pdf.bounding_box([5, y_position - 290], :width => 275, :height => 20) do
              # Pickup block
              pdf.fill_color "eeeeee"
              pdf.fill_rectangle [-4, 26], 278, 18
              pdf.fill_color "000000"
            end  
            pdf.bounding_box([5, y_position - 290], :width => 80, :height => 40) do
              pdf.text " ", inline_format: true, size: 10
              pdf.move_down 5
              pdf.text "<b>Fecha:</b>", inline_format: true, size: 10
              pdf.text "<b>Lugar:</b>", inline_format: true, size: 10
            end
            pdf.bounding_box([80, y_position - 290], :width => 100, :height => 40) do
              pdf.text "<b>ENTREGA</b>", inline_format: true, size: 10
              pdf.move_down 5
              pdf.text "#{booking.date_from.strftime('%d-%m-%Y')} #{booking.time_from}", inline_format: true, size: 10
              pdf.text "#{booking.pickup_place}", inline_format: true, size: 10              
            end            
            # Return place
            pdf.bounding_box([5, y_position - 340], :width => 275, :height => 20) do
              pdf.fill_color "eeeeee"
              pdf.fill_rectangle [-4, 26], 278, 18
              pdf.fill_color "000000"
            end              
            pdf.bounding_box([5, y_position - 340], :width => 80, :height => 40) do
              pdf.text " ", inline_format: true, size: 10
              pdf.move_down 5
              pdf.text "<b>Fecha:</b>", inline_format: true, size: 10
              pdf.text "<b>Lugar:</b>", inline_format: true, size: 10
            end
            pdf.bounding_box([80, y_position - 340], :width => 100, :height => 40) do
              pdf.text "<b>DEVOLUCIÓN</b>", inline_format: true, size: 10
              pdf.move_down 5
              pdf.text "#{booking.date_to.strftime('%d-%m-%Y')} #{booking.time_to}", inline_format: true, size: 10
              pdf.text "#{booking.return_place}", inline_format: true, size: 10              
            end  
            # Comments          
            pdf.bounding_box([5, y_position - 390], :width => 275, :height => 20) do
              pdf.fill_color "eeeeee"
              pdf.fill_rectangle [-4, 26], 278, 18
              pdf.fill_color "000000"
            end              
            pdf.bounding_box([5, y_position - 390], :width => 275, :height => 40) do
              pdf.text "<b>COMENTARIOS</b>", inline_format: true, size: 10
              pdf.move_down 5
              pdf.text "#{booking.comments}", inline_format: true, size: 10
            end

            # Column 2 ==============================

            pdf.bounding_box([285, y_position], :width => 269, :height => 40) do
              # Driver 
              pdf.fill_color "eeeeee"
              pdf.fill_rectangle [-4, 46], 268, 18
              pdf.fill_color "000000"
              pdf.text "<b>DATOS SOBRE EL CONDUCTOR PRINCIPAL</b>", inline_format: true, size: 10, align: :center
              pdf.move_down 5
              pdf.text "#{booking.driver_name} #{booking.driver_surname}", inline_format: true, size:10
            end 

            pdf.bounding_box([285, y_position - 40], :width => 269, :height => 50) do
              # Driver Adress 
              pdf.fill_color "eeeeee"
              pdf.fill_rectangle [-4, 56], 268, 18
              pdf.fill_color "000000"
              pdf.text "<b>DIRECCION PERMANENTE</b>", inline_format: true, size: 10, align: :center
              pdf.move_down 5
              if booking.driver_address
                pdf.text "#{booking.driver_address.street} #{booking.driver_address.number} #{booking.driver_address.complement}", inline_format: true, size: 10
                pdf.text "#{booking.driver_address.city} #{booking.driver_address.state}", inline_format: true, size: 10
                pdf.text "#{booking.driver_address.zip} #{booking.driver_address.country}", inline_format: true, size: 10
              else
                pdf.text "", inline_format: true, size: 10
                pdf.text "", inline_format: true, size: 10
                pdf.text "", inline_format: true, size: 10
              end  
            end 

            pdf.bounding_box([285, y_position - 100], :width => 269, :height => 40) do
              # Phone number 
              pdf.fill_color "eeeeee"
              pdf.fill_rectangle [-4, 46], 268, 18
              pdf.fill_color "000000"
              pdf.text "<b>TELÉFONOS</b>", inline_format: true, size: 10, align: :center
              pdf.move_down 5
              pdf.text "#{booking.customer_phone}     #{booking.customer_mobile_phone}", inline_format: true, size:10, align: :center
            end                 

            # Line under phone number
            pdf.stroke_color "000000"
            pdf.stroke { pdf.line [280, y_position - 135], [550, y_position - 135] }

            pdf.bounding_box([285, y_position - 140], :width => 90, :height => 100) do
              # Driver data col 1
              pdf.text "<b>Nif</b>", inline_format: true, size: 10
              pdf.text "<b>Nacionalidad</b>", inline_format: true, size: 10
              pdf.text "<b>Lugar Exp.</b>", inline_format: true, size: 10
              pdf.text "<b>Fecha Exp.</b> ", inline_format: true, size: 10
              pdf.text "<b>Permiso Cond.</b>", inline_format: true, size: 10
              pdf.text "<b>Lugar Exp.</b>", inline_format: true, size: 10
              pdf.text "<b>Fecha Exp.</b>", inline_format: true, size: 10
            end
              
            pdf.bounding_box([285 + 90, y_position - 140], :width => 159, :height => 80) do
              # Driver data col 2
              pdf.text "#{booking.driver_document_id}", inline_format: true, size: 10
              pdf.text "#{booking.driver_origin_country}", inline_format: true, size: 10
              pdf.text "#{booking.driver_origin_country}", inline_format: true, size: 10
              pdf.text "#{booking.driver_document_id_date ? booking.driver_document_id_date.strftime('%d-%m-%Y') : ''}    <b>Cad.</b> #{booking.driver_document_id_expiration_date ? booking.driver_document_id_expiration_date.strftime('%d-%m-%Y') : ''}", inline_format: true, size: 10
              pdf.text "#{booking.driver_driving_license_number}", inline_format: true, size: 10
              pdf.text "#{booking.driver_driving_license_country}", inline_format: true, size: 10
              pdf.text "#{booking.driver_driving_license_date ? booking.driver_driving_license_date.strftime('%d-%m-%Y') : ''}    <b>Cad.</b> #{booking.driver_driving_license_expiration_date ? booking.driver_driving_license_expiration_date.strftime('%d-%m-%Y') : ''}", inline_format: true, size: 10
            end         

            # Line under driver data
            pdf.stroke_color "000000"
            pdf.stroke { pdf.line [280, y_position - 225], [550, y_position - 225] }

            pdf.bounding_box([285, y_position - 230], :width => 210, :height => 30) do
              # Days column 1
              pdf.text "<b>Días facturados</b>", inline_format: true, size: 10
              pdf.text "<b>Grupo alquilado/facturado</b>", inline_format: true, size: 10
            end
            pdf.bounding_box([485, y_position - 230], :width => 56, :height => 30) do
              # Days column 2
              pdf.text "#{booking.days}", inline_format: true, size: 10, align: :right
              pdf.text "#{(booking.booking_lines and booking.booking_lines.size > 0) ? booking.booking_lines.first.item_id : ''}", inline_format: true, size: 10, align: :right
            end
            # Separator between Days column 1 and column 2
            pdf.stroke { pdf.line [480, y_position - 225], [480, y_position - 255] }

            pdf.bounding_box([285, y_position - 260], :width => 269, :height => 50) do
              # Invoicing
              pdf.fill_color "eeeeee"
              pdf.fill_rectangle [-4, 56], 268, 18
              pdf.fill_color "000000"
              pdf.text "<b>CONCEPTOS FACTURADOS</b>", inline_format: true, size: 10
              pdf.move_down 5
            end

            pdf.bounding_box([285, y_position - 275], :width => 80, :height => 20) do
              # Invoicing column 1
              pdf.text "Alquiler", inline_format: true, size: 10
            end
            pdf.bounding_box([365, y_position - 275], :width => 45, :height => 20) do
              # Invoicing column 2
              pdf.text "#{booking.days} día(s)", inline_format: true, size: 10
            end            
            pdf.bounding_box([410, y_position - 275], :width => 130, :height => 20) do
              # Invoicing column 4
              pdf.text "#{'%.2f' % booking.item_cost}€", inline_format: true, size: 10, align: :right
            end                          

            pdf.bounding_box([285, y_position - 375], :width => 80, :height => 20) do
              # Total column 1
              pdf.text "<b>TOTAL</b>    21.00%", inline_format: true, size: 10
            end
            pdf.bounding_box([365, y_position - 375], :width => 45, :height => 20) do
              # Total column 2
              pdf.text "<b>IVA Inc.</b>", inline_format: true, size: 10
            end            
            pdf.bounding_box([410, y_position - 375], :width => 130, :height => 20) do
              # Total column 4
              pdf.text "<b>#{'%.2f' % booking.total_cost}€</b>", inline_format: true, size: 10, align: :right
            end    

            # Line over total
            pdf.stroke_color "000000"
            pdf.stroke { pdf.line [280, y_position - 370], [550, y_position - 370] }

            # Line under total
            pdf.stroke_color "000000"
            pdf.stroke { pdf.line [280, y_position - 390], [550, y_position - 390] }

            # Separator between Invoicing column 3 and column 4
            pdf.stroke { pdf.line [480, y_position - 472], [480, y_position - 272] }

            return pdf

          end

        end
      end
    end
  end
end