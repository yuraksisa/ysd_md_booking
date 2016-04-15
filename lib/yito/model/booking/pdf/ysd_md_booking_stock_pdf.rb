require 'prawn' unless defined?Prawn
require 'prawn/table' unless defined?Prawn::Table
module Yito
  module Model
    module Booking
      module Pdf
        class Stock

          def build
            stock_list = ::Yito::Model::Booking::BookingItem.all(
               :conditions => {:active => true},
               :order => [:category_code, :reference, :stock_model, :stock_plate])

            pdf = Prawn::Document.new()
            font_file = File.expand_path(File.join(File.dirname(__FILE__), "../../../../..", 
            "fonts", "DejaVuSans.ttf"))
            pdf.font font_file
                        
            pdf.text "Stock", inline_format: true, size: 18
            pdf.move_down 10

            if stock_list.size == 0
              pdf.text "No hay stock"
            else
              build_table(stock_list, pdf) 
            end
            
            return pdf
          end

          private

          def build_table(stock_list, pdf)
            
            table_data = []
            
            header = ["Producto"]
            header << "Referencia"
            header << "Modelo"
            header << "Matricula"
            header << "Carac. 1"
            header << "Carac. 2"
            header << "Carac. 3"
            table_data << header

            stock_list.each do |stock|
              data = [stock.category_code,
                      stock.reference,
                      stock.stock_model,
                      stock.stock_plate,
                      stock.characteristic_1,
                      stock.characteristic_2,
                      stock.characteristic_3]
              table_data << data                                 
            end

            pdf.table(table_data, width: pdf.bounds.width) do |t|
              t.column(0).style(size: 8, width: 70)	
              t.column(1).style(size: 8, width: 100)
              t.column(2).style(size: 8)
              t.column(3).style(size: 8, width: 70)
              t.column(4).style(size: 8)              
              t.column(5).style(size: 8)
              t.column(6).style(size: 8)
            end   

          end	

        end
      end
    end
  end
end