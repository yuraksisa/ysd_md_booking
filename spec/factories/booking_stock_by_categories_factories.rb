#
# Stock by categories
#
#  two categories: A, B
#  category A : three items 1111AAA, 2222AAA, 3333AAA
#  category B : two items 1111BBB, 2222BBB 
#     
#
FactoryBot.define do
  
  factory(:booking_category_a, class: Yito::Model::Booking::BookingCategory) do
    code { 'A' }
    type { :category_of_resources }
    name { 'Group A' }
  end
  
  factory(:booking_category_b, class: Yito::Model::Booking::BookingCategory) do
    code { 'B' }
    type { :category_of_resources }
    name { 'Group B' }
  end

  factory(:booking_item_1111AAA_category_a, class: Yito::Model::Booking::BookingItem) do
    reference { '1111-AAA' }
    association :category, factory: :booking_category_a
  end	

  factory(:booking_item_2222AAA_category_a, class: Yito::Model::Booking::BookingItem) do
    reference { '2222-AAA' }
    association :category, factory: :booking_category_a
  end	

  factory(:booking_item_3333AAA_category_a, class: Yito::Model::Booking::BookingItem) do
    reference { '3333-AAA' }
    association :category, factory: :booking_category_a
  end	

  factory(:booking_item_1111BBB_category_b, class: Yito::Model::Booking::BookingItem) do
    reference { '1111-BBB' }
    association :category, factory: :booking_category_b
  end	

  factory(:booking_item_2222BBB_category_b, class: Yito::Model::Booking::BookingItem) do
    reference { '2222-BBB' }
    association :category, factory: :booking_category_b
  end

end	