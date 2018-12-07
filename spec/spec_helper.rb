require 'ysd_md_booking'
require 'ysd_md_configuration'
require 'ysd_md_translation'   # Necessary form photo gallery
require 'ysd_md_photo_gallery' # Necessary for aspects
require 'dm-sql-finders'       # Necessary for search (Extension as active-record)

require 'rspec/its'
require 'factory_bot' # Include factory bot
require 'database_cleaner'

# http://www.betterspecs.org/
# https://devhints.io/factory_bot

# https://github.com/thoughtbot/factory_bot/issues/372

# Allow sqlite transaction save point
module DataMapper
  class Transaction
  	module SqliteAdapter
      def supports_savepoints?
        true
      end
  	end
  end
end

# Configure FactoryBot
RSpec.configure do |config|
  config.include FactoryBot::Syntax::Methods

  config.before(:suite) do
    # To load factories
    FactoryBot.find_definitions
    # To clear database between tests
    DatabaseCleaner.strategy = :transaction
    DatabaseCleaner.clean_with(:truncation)
  end

  # To clear database between tests
  config.around(:each) do |example|
    DatabaseCleaner.cleaning do
      example.run
    end
  end

end

# Setup DataMapper for FactoryBot
class CreateForDataMapper
  def initialize
    @default_strategy = FactoryBot::Strategy::Create.new
  end

  delegate :association, to: :@default_strategy

  def result(evaluation)
    evaluation.singleton_class.send :define_method, :create do |instance|
      instance.save ||
        raise(instance.errors.send(:errors).map{|attr,errors| "- #{attr}: #{errors}" }.join("\n"))
    end

    @default_strategy.result(evaluation)
  end
end

FactoryBot.register_strategy(:create, CreateForDataMapper)

# -- Delayed worker

Delayed::Worker.backend = :data_mapper


# Aspects
Plugins::ModelAspect.aspect_applicable(FieldSet::Album, Yito::Model::Booking::BookingCategory)
Plugins::ModelAspect.aspect_applicable(FieldSet::Album, Yito::Model::Booking::BookingExtra)
Plugins::ModelAspect.aspect_applicable(FieldSet::Album, Yito::Model::Booking::Activity)
Plugins::ModelAspect.aspect_applicable(FieldSet::Album, Yito::Model::Booking::BookingCategoriesSalesChannel)
Plugins::ModelAspect.apply  

# Setup datamapper
DataMapper::Logger.new(STDOUT, :debug)
DataMapper.setup :default, "sqlite3::memory:"
DataMapper::Model.raise_on_save_failure = false
DataMapper.finalize 

DataMapper.auto_migrate!