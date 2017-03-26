require 'ysd_md_booking'
require 'rspec/its'

module DataMapper
  class Transaction
  	module SqliteAdapter
      def supports_savepoints?
        true
      end
  	end
  end
end

Delayed::Worker.backend = :data_mapper

DataMapper::Logger.new(STDOUT, :debug)
DataMapper.setup :default, "sqlite3::memory:"
DataMapper::Model.raise_on_save_failure = false
DataMapper.finalize 

DataMapper.auto_migrate!