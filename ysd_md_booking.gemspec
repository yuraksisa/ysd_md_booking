Gem::Specification.new do |s|
  s.name    = "ysd_md_booking"
  s.version = "0.2.4"
  s.authors = ["Yurak Sisa Dream"]
  s.date    = "2012-03-06"
  s.email   = ["yurak.sisa.dream@gmail.com"]
  s.files   = Dir['lib/**/*.rb','templates/**/*.erb']
  s.summary = "A DattaMapper-based model for booking"
  
  s.add_runtime_dependency "data_mapper", "1.2.0"
  s.add_runtime_dependency "json"

  s.add_runtime_dependency "ysd_service_postal"  
  s.add_runtime_dependency "ysd_md_business_events" # Business events
  s.add_runtime_dependency "ysd_md_payment"
  
  s.add_development_dependency "rake"
  s.add_development_dependency "rspec"
  s.add_development_dependency "dm-sqlite-adapter" # Model testing using sqlite

end
