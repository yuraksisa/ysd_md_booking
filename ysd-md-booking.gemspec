Gem::Specification.new do |s|
  s.name    = "ysd_md_booking"
  s.version = "0.1"
  s.authors = ["Yurak Sisa Dream"]
  s.date    = "2012-03-06"
  s.email   = ["yurak.sisa.dream@gmail.com"]
  s.files   = Dir['lib/**/*.rb','templates/**/*.erb']
  s.summary = "A DattaMapper-based model for booking"
  
  s.add_runtime_dependency "dm-core"
  s.add_runtime_dependency "ysd-md-business_events"
end
