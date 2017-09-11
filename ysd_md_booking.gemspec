Gem::Specification.new do |s|
  s.name    = "ysd_md_booking"
  s.version = "0.4.46"
  s.authors = ["Yurak Sisa Dream"]
  s.date    = "2012-03-06"
  s.email   = ["yurak.sisa.dream@gmail.com"]
  s.files   = Dir['lib/**/*.rb','templates/**/*.erb','i18n/**/*.yml', 'spec/**/*.rb', 'fonts/**/*.ttf']
  s.summary = "A DattaMapper-based model for booking"
  
  s.add_runtime_dependency "data_mapper", "1.2.0"
  s.add_runtime_dependency "json"
  s.add_runtime_dependency "dm-observer"
  s.add_runtime_dependency "delayed_job"
  s.add_runtime_dependency "delayed_job_data_mapper"

  s.add_runtime_dependency "prawn"
  s.add_runtime_dependency "prawn-table"

  s.add_runtime_dependency "ysd_service_postal"  
  s.add_runtime_dependency "ysd_md_business_events" # Business events
  s.add_runtime_dependency "ysd_md_calendar"
  s.add_runtime_dependency "ysd_md_payment"
  s.add_runtime_dependency "ysd_md_yito"
  s.add_runtime_dependency "ysd_md_cms"
  s.add_runtime_dependency "ysd_md_audit"
  s.add_runtime_dependency "ysd_md_location"
  s.add_runtime_dependency "ysd_md_translation"
  s.add_runtime_dependency "ysd_md_rates"
      
  s.add_development_dependency "rake"
  s.add_development_dependency "rspec"
  s.add_development_dependency "rspec-its"
  s.add_development_dependency "dm-sqlite-adapter" # Model testing using sqlite

end
