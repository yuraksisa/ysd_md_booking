require 'ysd_md_booking_notification'
require 'ysd_md_booking_extra'
require 'ysd_md_booking_guests'
require 'ysd_md_booking_driver'
require 'ysd_md_booking_flight'
require 'ysd_md_booking_heightweight'
require 'ysd_md_booking_pickup_return'
require 'yito/model/booking/ysd_md_booking_activity_queries'
require 'yito/model/booking/ysd_md_booking_queries'
require 'yito/model/booking/ysd_md_booking_queries_mysql'
require 'yito/model/booking/ysd_md_booking_queries_postgresql'
require 'yito/model/booking/ysd_md_booking_queries_sqlite'
require 'yito/model/booking/pdf/ysd_md_booking_pickup_return_pdf'
require 'yito/model/booking/pdf/ysd_md_booking_reservations_pdf'
require 'yito/model/booking/pdf/ysd_md_booking_customers_pdf'
require 'yito/model/booking/pdf/ysd_md_booking_stock_pdf'
require 'yito/model/booking/pdf/ysd_md_booking_charges_pdf'
require 'yito/model/booking/ysd_md_booking_product_family'
require 'yito/model/booking/ysd_md_booking_catalog'
require 'yito/model/booking/ysd_md_booking_category'
require 'yito/model/booking/ysd_md_booking_extra'
require 'yito/model/booking/ysd_md_booking_catalog_extra'
require 'yito/model/booking/ysd_md_booking_item'
require 'yito/model/booking/ysd_md_booking_configuration'
require 'yito/model/booking/ysd_md_booking_availability'
require 'yito/model/booking/ysd_md_booking_pickup_return_place_definition'
require 'yito/model/booking/ysd_md_booking_pickup_return_place'
require 'yito/model/booking/ysd_md_booking_generator'
require 'yito/model/booking/ysd_md_booking_templates'
require 'yito/model/booking/ysd_md_booking_activity'
require 'yito/model/booking/ysd_md_booking_activity_date'
require 'ysd_md_booking_model'
require 'ysd_md_booking_line'
require 'ysd_md_booking_line_resource'
require 'ysd_md_booking_preservation'
require 'ysd_md_booking_charge'
require 'ysd_md_booking_charge_observer'
require 'commands/ysd_new_booking_command'

require 'ysd_md_translation' unless defined?Yito::Translation

module BookingDataSystem
  extend Yito::Translation::ModelR18

  def self.r18n
    check_r18n!(:bookings_r18n, File.expand_path(File.join(File.dirname(__FILE__), '..', 'i18n')))
  end

end