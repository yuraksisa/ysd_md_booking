require 'date' unless defined?DateTime
require 'singleton' unless defined?Singleton

module Yito
  module Model
    module Booking
      #
      # Data Creation module
      #
      class DataCreation
            include Singleton

        NAMES = ['Abel', 'Antonio', 'Carmen', 'David', 'Eduardo',
                 'Javier', 'Jorge', 'Juan', 'Laura', 'Maria',
                 'Maite', 'Oscar', 'Paula',
                 'Raul', 'Ruben', 'Sergio']

        SURNAMES = ['Perez Gomez', 'Gomez Perez', 'Fernandez Ruiz',
          'Martinez Perez', 'Santamaria Gil', 'Lopez Perez',
          'Camps Sintes', 'Catchot Pons', 'Bervel Sanchez',
          'Bonet Piñol', 'Perez Perez', 'Martinez Fernandez']

        EMAILS = ['demo@mybooking.es']

        PHONES = ['935551010','6661010']

        DOCUMENT_IDS = ['5555555R']

        TIMES = ['10:00','10:30','11:00','11:30','16:00','18:00']

        DRIVER_DATE_OF_BIRTH_FROM = Date.new(1950, 1, 1)
        DRIVER_DATE_OF_BIRTH_TO = Date.new(1979, 12, 31)
        DRIVER_DRIVING_LICENSE_FROM = Date.new(1998, 1, 1)
        DRIVER_DRIVING_LICENSE_TO = Date.today - 365
        DRIVER_DRIVING_LICENSE_COUNTRIES = ['España']

        PLANNING_COLOR = ['#28C250','#447EF9','#A744F9','#F7487D']

        COMMENTS = <<-TEXT
            Lorem ipsum dolor sit amet, consectetuer adipiscing elit. Aenean commodo ligula eget dolor. Aenean massa.
            Cum sociis natoque penatibus et magnis dis parturient montes, nascetur ridiculus mus. Donec quam felis,
            ultricies nec, pellentesque eu, pretium quis, sem. Nulla consequat massa quis enim.
        TEXT

        PAYMENT_METHODS = ['bank_transfer','cash']

        def initialize

        end

        #
        # Create
        #
        def create_data(num_of_bookings, date_from, date_to, max_products=1, max_extras=1)

          notify_value = SystemConfiguration::Variable.get_value('booking.send_notifications', "true").to_bool
          SystemConfiguration::Variable.set_value('booking.send_notifications', 'false', {:module => :booking, :description => "Notify confirmation"})

          products = ::Yito::Model::Booking::BookingCategory.all
          extras = ::Yito::Model::Booking::BookingExtra.all
          stocks = ::Yito::Model::Booking::BookingItem.all

          pickup_return_places_definition = ::Yito::Model::Booking::PickupReturnPlaceDefinition.first
          pickup_places = pickup_return_places_definition.pickup_return_places.size > 0 ? pickup_return_places_definition.pickup_return_places.select {|item| item.is_pickup} : []
          return_places = pickup_return_places_definition.pickup_return_places.size > 0 ? pickup_return_places_definition.pickup_return_places.select {|item| item.is_return} : []

          begin
            # Create reservations
            (1..num_of_bookings).each do |element|

              creation_date = Date.today - (num_of_bookings - element - 1)
              p "creation_date #{creation_date}"
              reservation_date_from = date_from + (date_to - date_from) * rand
              time_from = TIMES[rand(0..TIMES.size-1)]
              reservation_date_to = reservation_date_from + rand(1..10)
              time_to = TIMES[rand(0..TIMES.size-1)]

              pickup_place = pickup_places.size > 0 ? pickup_places[rand(0..pickup_places.size-1)].name : []
              return_place = return_places.size > 0 ? return_places[rand(0..return_places.size-1)].name : []

              customer_name = NAMES[rand(0..NAMES.size-1)]
              customer_surname = SURNAMES[rand(0..SURNAMES.size-1)]
              customer_email = EMAILS[rand(0..EMAILS.size-1)]
              customer_phone = PHONES[rand(0..PHONES.size-1)]

              driver_name = customer_name
              driver_surname = customer_surname
              driver_document_id = DOCUMENT_IDS[rand(0..DOCUMENT_IDS.size-1)]
              driver_driving_license_number = driver_document_id
              driver_driving_license_date =  DRIVER_DATE_OF_BIRTH_FROM + (DRIVER_DATE_OF_BIRTH_TO - DRIVER_DATE_OF_BIRTH_FROM) * rand
              driver_date_of_birth =  DRIVER_DRIVING_LICENSE_FROM + (DRIVER_DRIVING_LICENSE_TO - DRIVER_DRIVING_LICENSE_FROM) * rand
              driver_driving_license_country = DRIVER_DRIVING_LICENSE_COUNTRIES[rand(0..DRIVER_DRIVING_LICENSE_COUNTRIES.size-1)]
              driver_address= LocationDataSystem::Address.new

              planning_color = PLANNING_COLOR[rand(0..PLANNING_COLOR.size-1)]
              comments = COMMENTS

              BookingDataSystem::Booking.transaction do
                booking = BookingDataSystem::Booking.create(date_from: reservation_date_from,
                                                            time_from: time_from,
                                                            pickup_place: pickup_place,
                                                            date_to: reservation_date_to,
                                                            time_to: time_to,
                                                            return_place: return_place,
                                                            customer_name: customer_name,
                                                            customer_surname: customer_surname,
                                                            customer_email: customer_email,
                                                            customer_phone: customer_phone,
                                                            driver_name: driver_name,
                                                            driver_surname: driver_surname,
                                                            driver_document_id: driver_document_id,
                                                            driver_driving_license_number: driver_driving_license_number,
                                                            driver_driving_license_date: driver_driving_license_date,
                                                            driver_date_of_birth: driver_date_of_birth,
                                                            driver_driving_license_country: driver_driving_license_country,
                                                            driver_address: driver_address,
                                                            comments: comments,
                                                            planning_color: planning_color
                                                          )
                booking.update(creation_date: creation_date)
                (1..max_products).each do |item|
                  product = products[rand(0..products.size-1)]
                  booking.add_booking_line(product.code, 1)
                end

                (1..max_extras).each do |item|
                  extra = extras[rand(0..extras.size-1)]
                  booking.add_booking_extra(extra.code, 1)
                end

                # Confirm booking
                payment_method = PAYMENT_METHODS[rand(0..PAYMENT_METHODS.size-1)]
                booking.add_booking_charge(DateTime.now, booking.booking_amount, payment_method)

                # Assign stock
                booking.booking_line_resources.each do |booking_line_resource|
                  suitable_stocks = stocks.select {|item| item.category.code == booking_line_resource.booking_line.item_id}
                  stock = suitable_stocks[rand(0..suitable_stocks.size-1)]
                  booking_line_resource.assign_resource(stock.reference)
                end

              end

            end

          end

        rescue
          SystemConfiguration::Variable.set_value('booking.send_notifications', notify_value.to_s)
        end

      end
    end
  end
end
