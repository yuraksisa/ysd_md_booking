require 'data_mapper' unless defined?DataMapper

module BookingDataSystem

  #
  # Represent a prereservation of an stock item for a period
  #
  class BookingPrereservationLine
    include DataMapper::Resource

    storage_names[:default] = 'bookds_prereservation_lines'

    property :id, Serial
    property :booking_item_category, String, :length => 20
    property :booking_item_reference, String, :length => 50

    belongs_to :prereservation, 'BookingPrereservation', :child_key => [:prereservation_id]

  end
end