FactoryBot.define do
  
  factory(:booking_family_rent_a_car, class: Yito::Model::Booking::ProductFamily) do
     code { 'car' }
     product_type { :category_of_resources }
     business_type { :vehicle_rental }
     business_activity { :rental }
     time_to_from { true }
     time_start { '10:00' }
     time_end { '10:00' }
     cycle_of_24_hours { true }
  end	

  factory(:booking_family_rent_a_car_vehicles, class: Yito::Model::Booking::ProductFamily) do
     code { 'car_vehicles' }
     product_type { :resource }
     business_type { :vehicle_rental }
     business_activity { :rental }
     time_to_from { true }
     time_start { '10:00' }
     time_end { '10:00' }
     cycle_of_24_hours { true }
  end	

  factory(:settings_variable_item_family_rent_a_car, class: SystemConfiguration::Variable) do
     name { 'booking.item_family' }
     value { 'car' }
  end	

  factory(:settings_variable_item_family_rent_a_car_vehicles, class: SystemConfiguration::Variable) do
     name { 'booking.item_family' }
     value { 'car_vehicles' }
  end	

end  