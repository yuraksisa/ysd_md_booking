require 'spec_helper'

describe BookingDataSystem::Booking do 

  # Save booking
  #
  describe "#save" do

    context "One line - One resouce - One extra reservation" do

      subject do
        booking = create(:booking_with_one_line)
        booking.save
        booking
      end

      #its(:total_paid) { should == 0}
      #its(:total_pending) { should == 50}
      #its("booking_lines.size") { should == 1}
      #its("booking_line_resources.size") { should == 1}
      #its("booking_extras.size") { should == 1}

    end

  end  

end