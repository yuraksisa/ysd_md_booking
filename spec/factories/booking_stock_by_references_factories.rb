#
# Stock by references
#
#  two categories: A1, B1 (implicit creation of two resources A1, B1)
#     
#
FactoryBot.define do
  
  factory(:booking_category_reference_a1, class: Yito::Model::Booking::BookingCategory) do
    code { 'A1' }
    type { :resource }
    name { 'A1' }
  end
  
  factory(:booking_category_reference_b1, class: Yito::Model::Booking::BookingCategory) do
    code { 'B1' }
    type { :resource }
    name { 'B1' }
  end

end  