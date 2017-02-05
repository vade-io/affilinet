Gem::Specification.new do |s|
  s.name        = 'affilinet'
  s.version     = '0.3.0'
  s.date        = '2017-02-05'
  s.summary     = 'a simple ruby wrapper around the Affilinet SOAP API'
  s.description = ''
  s.authors     = ['Frank Eckert', 'Alexander Adam']

  s.add_runtime_dependency 'savon', '> 2'
  s.add_runtime_dependency 'addressable'
  s.add_runtime_dependency 'httpclient'
  s.add_runtime_dependency 'dotenv'
  s.add_runtime_dependency 'activerecord'
  s.add_runtime_dependency 'hashie'

  s.add_development_dependency 'rspec'
  s.add_development_dependency 'vcr'
  s.add_development_dependency 'webmock'
  # s.add_development_dependency 'rubocop'
  # s.add_development_dependency 'pry'

  s.email       = 'frank.ecker@donovo.org'
  s.files       = `git ls-files`.split($OUTPUT_RECORD_SEPARATOR)
end
