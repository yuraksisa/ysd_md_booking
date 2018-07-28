module Yito
  module Model
    module Booking
      module Dashboard

        def self.extended(model)
          model.extend ClassMethods
        end

        #
        #
        #
        module ClassMethods

          # ------------------------------------------ Count  -------------------------------------------------------

          #
          # Count picked up reservations by date
          #
          def count_pickup(date)

            conditions = Conditions::JoinComparison.new('$and',
                                                        [Conditions::Comparison.new(:date_from, '$eq', date),
                                                         Conditions::Comparison.new(:status, '$ne', [:pending_confirmation, :cancelled])])
            conditions.build_datamapper(BookingDataSystem::Booking).all.count

          end

          #
          # Count transit reservations by date
          #
          def count_transit(date)

            conditions = Conditions::JoinComparison.new('$and',
                                                        [Conditions::Comparison.new(:date_from, '$lte', date),
                                                         Conditions::Comparison.new(:date_to, '$gte', date),
                                                         Conditions::Comparison.new(:status, '$ne', [:pending_confirmation, :cancelled])])
            conditions.build_datamapper(BookingDataSystem::Booking).all.count

          end

          #
          # Count delivery reservations by date
          #
          def count_delivery(date)

            conditions = Conditions::JoinComparison.new('$and',
                                                        [Conditions::Comparison.new(:date_to, '$eq', date),
                                                         Conditions::Comparison.new(:status, '$ne', [:pending_confirmation, :cancelled])])
            conditions.build_datamapper(BookingDataSystem::Booking).all.count

          end

          #
          # Get the number of received reservations
          #
          def count_received_reservations(year)
            query_strategy.count_received_reservations(year)
          end

          #
          # Get the number of pending of confirmation reservations
          #
          def count_pending_confirmation_reservations(year)
            query_strategy.count_pending_confirmation_reservations(year)
          end

          #
          # Get the number of confirmed reservations
          #
          def count_confirmed_reservations(year)
            query_strategy.count_confirmed_reservations(year)
          end


          # -------------------------- Reservations analysis ---------------------------------------------------------

          #
          # Reservations by weekday
          #
          #
          def reservations_by_weekday(year)
            data = query_strategy.reservations_by_weekday(year)
            result = data.inject({}) do |result, value|
              result.store(value.day.to_i.to_s, value.count)
              result
            end
            (0..6).each do |item|
              result.store(item.to_s, 0) unless result.has_key?(item.to_s)
            end
            result
          end

          #
          # Reservations by category
          #
          def reservations_by_category(year)

            data = query_strategy.reservations_by_category(year)
            result = data.inject({}) do |result, value|
              result.store(value.item_id, {value: value.count,
                                           color: "#%06x" % (rand * 0xffffff),
                                           highlight: "#%06x" % (rand * 0xffffff),
                                           label: value.item_id})
              result
            end

            result

          end

          #
          # Reservations by status
          #
          def reservations_by_status(year)

            data = query_strategy.reservations_by_status(year)

            result = data.inject({}) do |result, value|
              status = case value.status
                         when 1
                           BookingDataSystem.r18n.t.booking_status.pending_confirmation
                         when 2
                           BookingDataSystem.r18n.t.booking_status.confirmed
                         when 3
                           BookingDataSystem.r18n.t.booking_status.in_progress
                         when 4
                           BookingDataSystem.r18n.t.booking_status.done
                         when 5
                           BookingDataSystem.r18n.t.booking_status.cancelled
                       end

              color = case value.status
                        when 1
                          'yellow'
                        when 2
                          'green'
                        when 3
                          'blue'
                        when 4
                          'black'
                        when 5
                          'red'

                      end

              result.store(status, {value: value.count,
                                    color: color,
                                    highlight: "#%06x" % (rand * 0xffffff),
                                    label: status})
              result
            end

            result

          end

          #
          # The last 30 days reservations
          #
          def last_30_days_reservations

            months = ['E','F','M','A','My','J','Jl','A','S','O','N','D']

            result = {}
            (0..29).reverse_each do |item|
              today = Date.today - item
              key = "#{today.day}#{months[today.month-1]}"
              result.store(key, 0)
            end

            data = query_strategy.last_30_days_reservations
            data.each do |item|
              today = Date.today - item.period
              key = "#{today.day}#{months[today.month-1]}"
              result.store(key, item.occurrences) if result.has_key?(key)
              result
            end
            result

          end

          # ----------------------------------- Billing summary ----------------------------------------------------

          #
          # Get the products total billing
          #
          def products_billing_total(year)
            query_strategy.products_billing_total(year).first
          end

          #
          # Get the extras total billing
          #
          def extras_billing_total(year)
            result = query_strategy.extras_billing_total(year)
            if result.nil?
              value = 0
            else
              value = (result.first || 0)
              if result.size == 2
                value += (result.last || 0)
              end
            end
            return value
          end

          # -------------------------------- Charges ---------------------------------------------------------------

          #
          # Total amount that should be charged in a period of time
          #
          def total_should_charged(date_from, date_to)
            query = <<-QUERY
                      select sum(b.total_cost)
                      from bookds_bookings b
                      WHERE b.date_from >= ? and date_from <= ? and 
                            b.status NOT IN (1,5)
            QUERY
            repository.adapter.select(query, date_from, date_to).first
          end


          #
          # Get the total charged amount for a year
          #
          def total_charged(year)
            data = query_strategy.total_charged(year)
            detail = data.inject({}) do |result, value|
              result.store(value.payment_method, {value: value.total,
                                                  color: "#%06x" % (rand * 0xffffff),
                                                  highlight: "#%06x" % (rand * 0xffffff),
                                                  label: Payments.r18n.t.payment_methods[value.payment_method.to_sym]})
              result
            end

            result = {total: 0, detail: detail}
            data.each { |item| result[:total] += item.total}

            return result
          end

          #
          # Get the forecast charged for a period
          #
          def forecast_charged(date_from, date_to)
            result = {total: 0, detail: {}}
            month = date_from.month
            year = date_from.year
            last_month = date_to.month
            last_year = date_to.year
            until (month == last_month && year == last_year) do
              result[:detail].store("#{year}-#{month.to_s.rjust(2, '0')}", 0)
              if month == 12
                month = 1
                year += 1
              else
                month += 1
              end
            end
            data = query_strategy.forecast_charged(date_from, date_to)
            data.each do |item|
              result[:total] += item.total
              result[:detail][item.period] += item.total
            end
            return result
          end

          # ------------------------------ Stock cost summary ------------------------------------------------------

          #
          # Stock cost total
          # --------------------------------------------------------------------------------------------------------
          #
          # Get the inventary total cost
          #
          #
          def stock_cost_total
            query_strategy.stock_cost_total.first || 0
          end

        end

      end
    end
  end
end