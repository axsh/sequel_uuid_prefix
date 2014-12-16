Gem::Specification.new do |s|
  s.name        = 'sequel_uuid_prefix'
  s.version     = '1.0'
  s.date        = '2014-12-16'
  s.summary     = 'Sequel Model plugin that adds [0-9a-z] unique id prefixed by a custom string.'
  s.authors     = ['Axsh Co. LTD']
  s.email       = 'dev@axsh.net'
  s.files       = Dir.glob("{lib}/**/*") + %w(LICENSE README.md)
  s.homepage    = 'https://github.com/axsh/sequel_uuid_prefix'
  s.license     = 'LGPLv3'
end
