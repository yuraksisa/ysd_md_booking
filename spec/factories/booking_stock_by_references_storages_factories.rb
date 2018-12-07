#
# Reference stock in multiple storages
#
# ====================================
# 
#  2 rental storages
#
#  Rental Storage S1
#    Rental Location L1
#       Pickup Place L1PP1
#       Pickup Place L1PP2
#
#  Rental Storage S2
#    Rental Location L2
#       Pickup Place L2PP1
#
#  ------------------------
#
#  5 resources, 2 in S1 and 3 in S2
#
#  ReferenceCategory S1A1 - S1
#  ReferenceCategory S1A2 - S1
#  ReferenceCategory S2A1 - S2
#  ReferenceCategory S2A2 - S2
#  ReferenceCategory S2A3 - S2
#
#
FactoryBot.define do
  
  factory(:rental_storage_s1, class: Yito::Model::Booking::RentalStorage) do
    name { 'S1' }
  end

  factory(:rental_storage_s2, class: Yito::Model::Booking::RentalStorage) do
    name { 'S2' }
  end

  factory(:rental_location_l1, class: Yito::Model::Booking::RentalLocation) do
    code { 'L1' }
    association :rental_storage, factory: :rental_storage_s1
  end  

  factory(:rental_location_l2, class: Yito::Model::Booking::RentalLocation) do
    code { 'L2' }
    association :rental_storage, factory: :rental_storage_l2
  end

  factory(:pickup_place_l1pp1, class: Yito::Model::Booking::PickupReturnPlace) do
    name { 'L1PP1' }
    is_pickup { true }
    is_return { true }
    association :rental_location, factory: :rental_location_l1
  end

  factory(:pickup_place_l1pp2, class: Yito::Model::Booking::PickupReturnPlace) do
    name { 'L1PP2' }
    is_pickup { true }
    is_return { true }
    association :rental_location, factory: :rental_location_l1
  end

  factory(:pickup_place_l2pp1, class: Yito::Model::Booking::PickupReturnPlace) do
    name { 'L2PP1' }
    is_pickup { true }
    is_return { true }
    association :rental_location, factory: :rental_location_l2
  end


  factory(:booking_category_reference_storage_s1a1, class: Yito::Model::Booking::BookingCategory) do
    code { 'S1A1' }
    type { :resource }
    name { 'S1A1' }
    association :rental_storage, factory: :rental_storage_s1
  end
  
  factory(:booking_category_reference_storage_s1a2, class: Yito::Model::Booking::BookingCategory) do
    code { 'S1A2' }
    type { :resource }
    name { 'S1A2' }
    association :rental_storage, factory: :rental_storage_s1
  end

  factory(:booking_category_reference_storage_s2a1, class: Yito::Model::Booking::BookingCategory) do
    code { 'S2A1' }
    type { :resource }
    name { 'S2A1' }
    association :rental_storage, factory: :rental_storage_s2
  end
  
  factory(:booking_category_reference_storage_s2a2, class: Yito::Model::Booking::BookingCategory) do
    code { 'S2A2' }
    type { :resource }
    name { 'S2A2' }
    association :rental_storage, factory: :rental_storage_s2
  end

  factory(:booking_category_reference_storage_s2a3, class: Yito::Model::Booking::BookingCategory) do
    code { 'S2A3' }
    type { :resource }
    name { 'S2A3' }
    association :rental_storage, factory: :rental_storage_s2
  end

end  