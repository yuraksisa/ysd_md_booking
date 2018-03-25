require 'ysd_md_booking_notification'
require 'ysd_md_booking_extra'
require 'ysd_md_booking_guests'
require 'ysd_md_booking_driver'
require 'ysd_md_booking_flight'
require 'ysd_md_booking_heightweight'
require 'ysd_md_booking_pickup_return'
require 'ysd_md_booking_fuel'
require 'ysd_md_booking_crew'
require 'yito/model/booking/ysd_md_booking_supplements_calculation'
require 'yito/model/booking/ysd_md_booking_deposit_calculation'
require 'yito/model/booking/ysd_md_booking_cost_calculation'
require 'yito/model/booking/ysd_md_booking_driver_age_rule_definition'
require 'yito/model/booking/ysd_md_booking_driver_age_rule'
require 'yito/model/booking/ysd_md_booking_rental_location'
require 'yito/model/booking/ysd_md_booking_rental_location_user'
require 'yito/model/booking/ysd_md_booking_external_invoice'
require 'yito/model/booking/ysd_md_booking_pickup_return_units'
require 'yito/model/booking/ysd_md_booking_activity_queries'
require 'yito/model/booking/ysd_md_booking_shopping_cart_renting'
require 'yito/model/booking/ysd_md_booking_shopping_cart_extra_renting'
require 'yito/model/booking/ysd_md_booking_shopping_cart_item_renting'
require 'yito/model/booking/ysd_md_booking_shopping_cart_item_resource_renting'
require 'yito/model/booking/ysd_md_booking_activity_queries_mysql'
require 'yito/model/booking/ysd_md_booking_activity_queries_postgresql'
require 'yito/model/booking/ysd_md_booking_activity_queries_sqlite'
require 'yito/model/booking/ysd_md_booking_queries'
require 'yito/model/booking/ysd_md_booking_queries_mysql'
require 'yito/model/booking/ysd_md_booking_queries_postgresql'
require 'yito/model/booking/ysd_md_booking_queries_sqlite'
require 'yito/model/booking/pdf/ysd_md_booking_pickup_return_pdf'
require 'yito/model/booking/pdf/ysd_md_booking_customer_reservations_pdf'
require 'yito/model/booking/pdf/ysd_md_booking_reservations_pdf'
require 'yito/model/booking/pdf/ysd_md_booking_customers_pdf'
require 'yito/model/booking/pdf/ysd_md_booking_stock_pdf'
require 'yito/model/booking/pdf/ysd_md_booking_charges_pdf'
require 'yito/model/booking/ysd_md_booking_activity_translation'
require 'yito/model/booking/ysd_md_booking_category_translation'
require 'yito/model/booking/ysd_md_booking_extra_translation'
require 'yito/model/booking/ysd_md_booking_pickup_return_place_translation'
require 'yito/model/booking/ysd_md_booking_product_family'
require 'yito/model/booking/ysd_md_booking_catalog'
require 'yito/model/booking/ysd_md_booking_category_sales_management'
require 'yito/model/booking/ysd_md_booking_category'
require 'yito/model/booking/ysd_md_booking_extra'
require 'yito/model/booking/ysd_md_booking_catalog_extra'
require 'yito/model/booking/ysd_md_booking_item'
require 'yito/model/booking/ysd_md_booking_configuration'
require 'yito/model/booking/ysd_md_booking_availability'
require 'yito/model/booking/ysd_md_booking_pickup_return_place_definition'
require 'yito/model/booking/ysd_md_booking_pickup_return_place'
require 'yito/model/booking/ysd_md_booking_templates'
require 'yito/model/booking/ysd_md_booking_activity'
require 'yito/model/booking/ysd_md_booking_activity_date'
require 'yito/model/booking/ysd_md_booking_planned_activity'
require 'yito/model/booking/ysd_md_booking_category_historic'
require 'yito/model/booking/ysd_md_booking_item_historic'
require 'yito/model/booking/translation/ysd_md_translation_booking_activity'
require 'yito/model/booking/translation/ysd_md_translation_booking_category'
require 'yito/model/booking/translation/ysd_md_translation_booking_extra'
require 'yito/model/booking/translation/ysd_md_translation_booking_pickup_return_place'
require 'yito/model/booking/ysd_md_booking_categories_sales_channels'
require 'ysd_md_booking_model'
require 'ysd_md_booking_line'
require 'ysd_md_booking_line_resource'
require 'ysd_md_booking_preservation'
require 'ysd_md_booking_prereservation_line'
require 'ysd_md_booking_charge'
require 'ysd_md_booking_charge_observer'
require 'commands/ysd_new_booking_command'
require 'yito/model/booking/ysd_md_booking_renting_search'
require 'yito/model/booking/ysd_md_booking_renting_extra_search'
require 'yito/model/booking/ysd_md_booking_renting_calculator'

require 'yito/model/booking/data_creation'
require 'ysd_md_translation' unless defined?Yito::Translation

module BookingDataSystem
  extend Yito::Translation::ModelR18

  def self.r18n(locale=nil)
    path = File.expand_path(File.join(File.dirname(__FILE__), '..', 'i18n'))
    if locale.nil?
      check_r18n!(:bookings_r18n, path)
    else
      R18n::I18n.new(locale, path)
    end
  end

  def self.pickup_places

    place_definition = ::Yito::Model::Booking::PickupReturnPlaceDefinition.first
    pickup_places = ::Yito::Model::Booking::PickupReturnPlace.all(:conditions => {:place_definition_id => place_definition.id, :is_pickup => true}, :order => [:name.asc])

  end

  def self.return_places
    place_definition = ::Yito::Model::Booking::PickupReturnPlaceDefinition.first
    return_places = ::Yito::Model::Booking::PickupReturnPlace.all(conditions: {:place_definition_id => place_definition.id, :is_return => true}, order: [:name.asc])          
  end

  def self.pickup_return_timetable
  	['00:00','00:30','01:00','01:30','02:00','02:30','03:00','03:30',
  	 '04:00','04:30','05:00','05:30','06:00','06:30','07:00','07:30',
  	 '08:00','08:30','09:00','09:30','10:00','10:30','11:00','11:30',
  	 '12:00','12:30','13:00','13:30','14:00','14:30','15:00','15:30',
  	 '16:00','16:30','17:00','17:30','18:00','18:30','19:00','19:30',
  	 '20:00','20:30','21:00','21:30','22:00','22:30','23:00','23:30']
  end

end