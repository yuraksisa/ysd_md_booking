require 'ysd_md_booking_notification'
require 'ysd_md_booking_extra'
require 'ysd_md_booking_guests'
require 'ysd_md_booking_driver'
require 'ysd_md_booking_flight'
require 'ysd_md_booking_pickup_return'
require 'ysd_md_booking_model'
require 'ysd_md_booking_charge'
require 'ysd_md_booking_charge_observer'
require 'commands/ysd_new_booking_command'
require 'yito/booking/ysd_md_booking_product_family'
require 'ysd_md_translation' unless defined?Yito::Translation

module BookingDataSystem
  extend Yito::Translation::ModelR18

  def self.r18n
    check_r18n!(:bookings_r18n, File.expand_path(File.join(File.dirname(__FILE__), '..', 'i18n')))
  end

end