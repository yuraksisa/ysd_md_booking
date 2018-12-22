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

            logo = SystemConfiguration::Variable.get_value('booking.contract_logo')
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
            pdf.text_box "<b>#{company[:name]}</b>", inline_format: true, at: [400, 735], size: 9
            pdf.draw_text "#{company[:address_1]}", at: [400,715], size: 9
            pdf.draw_text "#{company[:zip]} - #{company[:city]} (#{company[:country]})", at:[400, 700], size: 9
            pdf.draw_text "#{company[:email]}", at: [400, 685], size: 9
            pdf.draw_text "#{company[:phone_number]}", at: [400, 670], size: 9
            pdf.draw_text "#{company[:document_id]}", at: [400, 655], size: 9

            # Contract information =========
            pdf.move_down 50
            pdf.text "<b>CONTRATO DE ALQUILER / RENTAL AGREEMENT</b>", inline_format: true, size: 14
            pdf.move_down 10

            # General border
            pdf.stroke_color "000000"
            pdf.stroke_rectangle [0, 650], 550, 540
          
            # =====================================================
            # 1 - Header : Vehicle data
            # =====================================================

            pdf.stroke_color "000000"
            pdf.stroke { pdf.line [0,590], [550, 590]} # Horizontal line total
            pdf.stroke { pdf.line [335, 650], [335, 590] } # Vertical line Vehicle Data / Pickup-return
            pdf.stroke { pdf.line [475, 650], [475, 590] } # Vertical line Pickup-return / Booking id

            y_position = pdf.cursor
            pdf.bounding_box([5, y_position], :width => 140, :height => 60) do
              pdf.fill_color "eeeeee"
              pdf.fill_rectangle [-4, 66], 140, 18
              pdf.fill_color "000000"
              pdf.text "<b>DATOS DEL VEHÍCULO</b>", inline_format: true, size: 10, align: :center
              pdf.move_down 2
              pdf.text "<b>Matrícula:</b> #{(booking.booking_lines and booking.booking_lines.size > 0 and booking.booking_lines.first.booking_line_resources and booking.booking_lines.first.booking_line_resources.size > 0 and booking.booking_lines.first.booking_line_resources.first) ? booking.booking_lines.first.booking_line_resources.first.booking_item_stock_plate : ''}", inline_format: true, size:10
              pdf.text "<b>Modelo:</b>", inline_format: true, size:10
              pdf.text "<b>Color:</b> #{(booking.booking_lines and booking.booking_lines.size > 0 and booking.booking_lines.first.booking_line_resources and booking.booking_lines.first.booking_line_resources.size > 0 and booking.booking_lines.first.booking_line_resources.first) ? booking.booking_lines.first.booking_line_resources.first.booking_item_characteristic_4 : ''}", inline_format: true, size:10
              pdf.text_box "#{(booking.booking_lines and booking.booking_lines.size > 0 and booking.booking_lines.first.booking_line_resources and booking.booking_lines.first.booking_line_resources.size > 0 and booking.booking_lines.first.booking_line_resources.first) ? booking.booking_lines.first.booking_line_resources.first.booking_item_stock_model : ''} ", 
                           at: [50, y_position - 610],
                           width: 300, height: 10, size: 10, overflow: :truncate
            end  

            pdf.bounding_box([145, y_position], :width => 190, :height => 60) do
              pdf.text "", size: 12
              pdf.text "<b>Grupo:</b> #{(booking.booking_lines and booking.booking_lines.size > 0) ? booking.booking_lines.first.item_id : ''}", inline_format: true, size:10
              pdf.text "<b>Combustible:</b> #{(booking.booking_lines and booking.booking_lines.size > 0 and booking.booking_lines.first.booking_line_resources and booking.booking_lines.first.booking_line_resources.size > 0 and booking.booking_lines.first.booking_line_resources.first) ? booking.booking_lines.first.booking_line_resources.first.booking_item_characteristic_1 : ''} ", inline_format: true, size:10
              pdf.text " ",inline_format: true, size: 10
              pdf.text "<b>Bastidor:</b>", inline_format: true, size:10     
            end 

            pdf.bounding_box([340, y_position], :width => 140, :height => 60) do        
              pdf.text "<b>Salida-gas:</b> #{booking.pickup_fuel}", inline_format: true, size:10
              pdf.text "<b>Entrada-gas:</b> #{booking.return_fuel}", inline_format: true, size:10
              pdf.text "<b>Salida-km:</b> #{(booking.booking_lines and booking.booking_lines.size > 0 and booking.booking_lines.first.booking_line_resources and booking.booking_lines.first.booking_line_resources.size > 0 and booking.booking_lines.first.booking_line_resources.first) ? booking.booking_lines.first.booking_line_resources.first.km_miles_on_pickup : ''}", inline_format: true, size:10
              pdf.text "<b>Entrada-km:</b> #{(booking.booking_lines and booking.booking_lines.size > 0 and booking.booking_lines.first.booking_line_resources and booking.booking_lines.first.booking_line_resources.size > 0 and booking.booking_lines.first.booking_line_resources.first) ? booking.booking_lines.first.booking_line_resources.first.km_miles_on_return : ''} ", inline_format: true, size:10
            end 

            pdf.bounding_box([480, y_position], :width => 70, :height => 60) do
              pdf.move_down 20
              pdf.text "<b>#{booking.id}</b>", inline_format: true, size:12, align: :center
            end      

            # =====================================================
            # 2 - Body
            # =====================================================

            # Column 1 separator
            pdf.stroke_color "000000"
            pdf.stroke { pdf.line [280, 590], [280, 110] }

            # Column 1 ==============================

            y_position = pdf.cursor
            pdf.bounding_box([5, y_position], :width => 275, :height => 60) do
              # Aditional Driver 
              pdf.fill_color "eeeeee"
              pdf.fill_rectangle [-4, 66], 278, 18
              pdf.fill_color "000000"
              pdf.text "<b>CONDUCTORES ADICIONALES</b>", inline_format: true, size: 10, align: :center
            end 
            pdf.bounding_box([5, y_position], :width => 130, :height => 60) do
              pdf.text " ", inline_format: true, size: 10
              pdf.move_down 5
              pdf.text "#{booking.additional_driver_1_name} #{booking.additional_driver_1_surname}", inline_format: true, size: 10
              pdf.move_down 5
              pdf.text "#{booking.additional_driver_1_driving_license_number}", inline_format: true, size: 10
            end
            pdf.bounding_box([135, y_position], :width => 130, :height => 60) do
              pdf.text " ", inline_format: true, size: 10
              pdf.move_down 5
              pdf.text "#{booking.additional_driver_2_name} #{booking.additional_driver_2_surname}", inline_format: true, size: 10
              pdf.move_down 5
              pdf.text "#{booking.additional_driver_2_driving_license_number}", inline_format: true, size: 10
            end            

            pdf.bounding_box([5, y_position - 60], :width => 275, :height => 200) do
              # Vehicle status
              pdf.fill_color "eeeeee"
              pdf.fill_rectangle [-4, 206], 278, 18
              pdf.fill_color "000000"
              pdf.text "<b>ESTADO DEL VEHÍCULO</b>", inline_format: true, size: 10, align: :center
              damages_img_path = File.expand_path(File.join(File.dirname(__FILE__), "../../../../..", "img", "contract-vehicle-damages.jpg"))
              pdf.image damages_img_path, width: 220, at: [0, 180]
              pdf.move_down 160
              pdf.text "<b>(1)</b> Roce <b>(2)</b> Golpe <b>(3)</b> Arañazo <b>(4)</b> Quemado <b>(5)</b> Roto", inline_format: true, size: 10, align: :center
            end 

            # Pickup - return time / place
            pdf.bounding_box([5, y_position - 250], :width => 275, :height => 20) do
              # Pickup block
              pdf.fill_color "eeeeee"
              pdf.fill_rectangle [-4, 26], 278, 18
              pdf.fill_color "000000"
            end  
            pdf.bounding_box([5, y_position - 250], :width => 50, :height => 40) do
              pdf.text " ", inline_format: true, size: 10
              pdf.move_down 5
              pdf.text "<b>Fecha:</b>", inline_format: true, size: 10
              pdf.text "<b>Lugar:</b>", inline_format: true, size: 10
            end
            pdf.bounding_box([50, y_position - 250], :width => 220, :height => 40) do
              pdf.text "<b>ENTREGA</b>", inline_format: true, size: 10
              pdf.move_down 5
              pdf.text "#{booking.date_from.strftime('%d-%m-%Y')} #{booking.time_from}", inline_format: true, size: 10
              pdf.text "#{booking.pickup_place}", inline_format: true, size: 10             
            end     
            
            # Return time / place
            pdf.bounding_box([5, y_position - 300], :width => 275, :height => 20) do
              # Return block
              pdf.fill_color "eeeeee"
              pdf.fill_rectangle [-4, 26], 278, 18
              pdf.fill_color "000000"
            end  
            pdf.bounding_box([5, y_position - 300], :width => 50, :height => 40) do
              pdf.text " ", inline_format: true, size: 10
              pdf.move_down 5
              pdf.text "<b>Fecha:</b>", inline_format: true, size: 10
              pdf.text "<b>Lugar:</b>", inline_format: true, size: 10
            end
            pdf.bounding_box([50, y_position - 300], :width => 220, :height => 40) do
              pdf.text "<b>DEVOLUCIÓN</b>", inline_format: true, size: 10
              pdf.move_down 5
              pdf.text "#{booking.date_to.strftime('%d-%m-%Y')} #{booking.time_to}", inline_format: true, size: 10
              pdf.text "#{booking.return_place}", inline_format: true, size: 10              
            end

            # Customer
            pdf.bounding_box([5, y_position - 350], :width => 275, :height => 20) do
              pdf.fill_color "eeeeee"
              pdf.fill_rectangle [-4, 26], 278, 18
              pdf.fill_color "000000"
            end              
            pdf.bounding_box([5, y_position - 350], :width => 50, :height => 40) do
              pdf.text " ", inline_format: true, size: 10
              pdf.move_down 5
              pdf.text "<b>Nombre:</b>", inline_format: true, size: 10
              pdf.text "<b>Nif:</b>", inline_format: true, size: 10
            end
            pdf.bounding_box([50, y_position - 350], :width => 150, :height => 40) do
              pdf.text "<b>DATOS DEL CLIENTE</b>", inline_format: true, size: 10
              pdf.move_down 5
              pdf.text "#{booking.customer_name} #{booking.customer_surname}", inline_format: true, size: 10
              pdf.text "#{booking.customer_document_id}", inline_format: true, size: 10              
            end
            pdf.bounding_box([150, y_position - 350], :width => 40, :height => 40) do
              pdf.text " ", inline_format: true, size: 10
              pdf.move_down 5
              pdf.text " ", inline_format: true, size: 10
              pdf.text "<b>Tfno:</b>", inline_format: true, size: 10
            end  
            pdf.bounding_box([190, y_position - 350], :width => 60, :height => 40) do
              pdf.text " ", inline_format: true, size: 10
              pdf.move_down 5
              pdf.text " ", inline_format: true, size: 10
              pdf.text "#{booking.customer_phone}", inline_format: true, size: 10              
            end                        
            # Comments          
            pdf.bounding_box([5, y_position - 400], :width => 275, :height => 20) do
              pdf.fill_color "eeeeee"
              pdf.fill_rectangle [-4, 26], 278, 18
              pdf.fill_color "000000"
            end              
            pdf.bounding_box([5, y_position - 400], :width => 275, :height => 40) do
              pdf.text "<b>COMENTARIOS</b>", inline_format: true, size: 10
              pdf.move_down 5
              pdf.text_box booking.comments, at: [0, y_position - 560],
                           width: 275, height: 50, size: 10, overflow: :truncate
              #pdf.text "#{booking.comments}", inline_format: true, size: 10
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

            pdf.bounding_box([285, y_position - 35], :width => 269, :height => 50) do
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

            pdf.bounding_box([285, y_position - 95], :width => 269, :height => 40) do
              # Driver Adress 
              pdf.fill_color "eeeeee"
              pdf.fill_rectangle [-4, 46], 268, 18
              pdf.fill_color "000000"
              pdf.text "<b>ALOJAMIENTO</b>", inline_format: true, size: 10, align: :center
              pdf.move_down 5
              pdf.text_box booking.destination_accommodation, at: [0, y_position - 560],
                           width: 269, height: 25, size: 10, overflow: :truncate
            end 

            pdf.bounding_box([285, y_position - 145], :width => 269, :height => 40) do
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
            pdf.stroke { pdf.line [280, y_position - 175], [550, y_position - 175] }

            pdf.bounding_box([285, y_position - 180], :width => 90, :height => 100) do
              # Driver data col 1
              pdf.text "<b>Nif</b>", inline_format: true, size: 10
              pdf.text "<b>Nacionalidad</b>", inline_format: true, size: 10
              pdf.text "<b>Lugar Exp.</b>", inline_format: true, size: 10
              pdf.text "<b>Fecha Exp.</b> ", inline_format: true, size: 10
              pdf.text "<b>Permiso Cond.</b>", inline_format: true, size: 10
              pdf.text "<b>Lugar Exp.</b>", inline_format: true, size: 10
              pdf.text "<b>Fecha Exp.</b>", inline_format: true, size: 10
            end
              
            pdf.bounding_box([285 + 90, y_position - 180], :width => 159, :height => 80) do
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
            pdf.stroke { pdf.line [280, y_position - 265], [550, y_position - 265] }

            pdf.bounding_box([285, y_position - 270], :width => 210, :height => 30) do
              # Days column 1
              pdf.text "<b>Días facturados</b>", inline_format: true, size: 10
              pdf.text "<b>Grupo alquilado/facturado</b>", inline_format: true, size: 10
            end
            pdf.bounding_box([485, y_position - 270], :width => 56, :height => 30) do
              # Days column 2
              pdf.text "#{booking.days}", inline_format: true, size: 10, align: :right
              pdf.text "#{(booking.booking_lines and booking.booking_lines.size > 0) ? booking.booking_lines.first.item_id : ''}", inline_format: true, size: 10, align: :right
            end

            # Separator between Days column 1 and column 2
            pdf.stroke { pdf.line [480, y_position - 265], [480, y_position - 295] }
            pdf.bounding_box([285, y_position - 300], :width => 269, :height => 50) do
              # Invoicing
              pdf.fill_color "eeeeee"
              pdf.fill_rectangle [-4, 56], 268, 18
              pdf.fill_color "000000"
              pdf.text "<b>CONCEPTOS FACTURADOS</b>", inline_format: true, size: 10
              pdf.move_down 5
            end

            # Product(s) ------------

            pdf.bounding_box([285, y_position - 315], :width => 80, :height => 20) do
              # Invoicing column 1
              pdf.text "Alquiler", inline_format: true, size: 10
            end
            pdf.bounding_box([365, y_position - 315], :width => 45, :height => 20) do
              # Invoicing column 2
              pdf.text "#{booking.days} día(s)", inline_format: true, size: 10, align: :right
            end            
            pdf.bounding_box([410, y_position - 315], :width => 130, :height => 20) do
              # Invoicing column 4
              pdf.text "#{'%.2f' % booking.item_cost}", inline_format: true, size: 10, align: :right
            end                          

            # Extras ---------------

            extra_idx = 1
            booking.booking_extras.each do |booking_extra|
              pdf.bounding_box([285, y_position - 315 - (extra_idx * 15)], :width => 80, :height => 15) do
                # Invoicing column 1
                pdf.text "#{booking_extra.extra_description_customer_translation}", inline_format: true, size: 10
              end
              pdf.bounding_box([365, y_position - 315 - (extra_idx * 15)], :width => 45, :height => 15) do
                # Invoicing column 2
                pdf.text "#{booking_extra.quantity}", inline_format: true, size: 10, align: :right
              end            
              pdf.bounding_box([410, y_position - 315 - (extra_idx * 15)], :width => 130, :height => 15) do
                # Invoicing column 4
                pdf.text "#{'%.2f' % booking_extra.extra_cost}", inline_format: true, size: 10, align: :right
              end 
              extra_idx += 1
            end       

            # Totals ----------------                    

            # TOTAL
            pdf.bounding_box([285, y_position - 400], :width => 80, :height => 20) do
              # Total column 1
              pdf.text "<b>TOTAL</b>    21.00%", inline_format: true, size: 10
            end
            pdf.bounding_box([365, y_position - 400], :width => 45, :height => 20) do
              # Total column 2
              pdf.text "<b>IVA Inc.</b>", inline_format: true, size: 10
            end            
            pdf.bounding_box([410, y_position - 400], :width => 130, :height => 20) do
              # Total column 4
              pdf.text "<b>#{'%.2f' % booking.total_cost}</b>", inline_format: true, size: 10, align: :right
            end    
            # Line over total
            pdf.stroke_color "000000"
            pdf.stroke { pdf.line [280, y_position - 395], [550, y_position - 395] }
            # Line under total
            pdf.stroke_color "000000"
            pdf.stroke { pdf.line [280, y_position - 415], [550, y_position - 415] }

            # PAID
            pdf.bounding_box([285, y_position - 420], :width => 80, :height => 20) do
              # Total column 1
              pdf.text "<b>PAGADO</b>", inline_format: true, size: 10
            end          
            pdf.bounding_box([410, y_position - 420], :width => 130, :height => 20) do
              # Total column 4
              pdf.text "<b>#{'%.2f' % booking.total_paid}</b>", inline_format: true, size: 10, align: :right
            end    
            # Line over total
            pdf.stroke_color "000000"
            pdf.stroke { pdf.line [280, y_position - 415], [550, y_position - 415] }
            # Line under total
            pdf.stroke_color "000000"
            pdf.stroke { pdf.line [280, y_position - 435], [550, y_position - 435] }

            # PENDING
            pdf.bounding_box([285, y_position - 440], :width => 80, :height => 20) do
              # Total column 1
              pdf.text "<b>PENDIENTE</b>", inline_format: true, size: 10
            end          
            pdf.bounding_box([410, y_position - 440], :width => 130, :height => 20) do
              # Total column 4
              pdf.text "<b>#{'%.2f' % booking.total_pending}</b>", inline_format: true, size: 10, align: :right
            end    
            # Line over total
            pdf.stroke_color "000000"
            pdf.stroke { pdf.line [280, y_position - 435], [550, y_position - 435] }
            # Line under total
            pdf.stroke_color "000000"
            pdf.stroke { pdf.line [280, y_position - 455], [550, y_position - 455] }

            # Separator between Invoicing column 3 and column 4
            pdf.stroke { pdf.line [480, y_position - 473], [480, y_position - 312] }

            # =====================================================
            # 3 - Footer : Terms and signatures
            # =====================================================
            pdf.move_down 15
            pdf.text "* He leído y entiendo los términos y condiciones del presente contrato de alquiler y autorizo con mi firma que todos los importes derivados de este alquiler sean cargados en mi tarjeta de crédito.", inline_format: true, size: 6
            pdf.text "* I have read and agreed the terms of this rental agreement and rental conditions, and I authorize with my signature that all amounts derived from this rent are charged to my creditcard, deposit or others.", inline_format: true, size: 6

            pdf.move_down 80
            pdf.text "De acuerdo con la nueva ley de Servicios de la Sociedad de la Información y Comercio Electrónico aprobada por el parlamento español y de la vigente Ley Orgánica 15 13/12/1999 de Protección de Datos española, le informamos que sus datos formam parte de un fichero automatizado, teniendo usted derecho de oposición, acceso, rectificación y cancelación de sus datos.", inline_format: true, size: 6

            # Signatures 
            pdf.stroke_color "000000"
            pdf.stroke { pdf.line [40, y_position - 535], [140, y_position - 535] }
            pdf.stroke_color "000000"
            pdf.stroke { pdf.line [160, y_position - 535], [260, y_position - 535] }
            pdf.stroke_color "000000"
            pdf.stroke { pdf.line [280, y_position - 535], [380, y_position - 535] }
            pdf.stroke_color "000000"
            pdf.stroke { pdf.line [400, y_position - 535], [500, y_position - 535] }                        
            
            pdf.bounding_box([30, y_position - 540], :width => 120, :height => 20) do
              # Customer
              pdf.text "<b>El arrendatario</b>", inline_format: true, size: 8, align: :center
              pdf.text "#{booking.customer_name} #{booking.customer_surname}", inline_format: true, size: 8, align: :center
            end
            pdf.bounding_box([150, y_position - 540], :width => 120, :height => 20) do
              # Main driver
              pdf.text "<b>El conductor principal</b>", inline_format: true, size: 8, align: :center
              pdf.text "#{booking.driver_name} #{booking.driver_surname}", inline_format: true, size: 8, align: :center
            end            
            pdf.bounding_box([270, y_position - 540], :width => 120, :height => 20) do
              # Delivery
              pdf.text "<b>Entregado por</b>", inline_format: true, size: 8, align: :center
            end 
            pdf.bounding_box([390, y_position - 540], :width => 120, :height => 20) do
              # Return
              pdf.text "<b>Recogido por</b>", inline_format: true, size: 8, align: :center
            end 

            return pdf

          end

        end
      end
    end
  end
end