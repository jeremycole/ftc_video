# frozen_string_literal: true

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'ftc_video/version'

Gem::Specification.new do |spec|
  spec.name          = 'ftc_video'
  spec.version       = FtcVideo::VERSION
  spec.authors       = ['Jeremy Cole']
  spec.email         = ['jeremy@jcole.us']

  spec.summary       = 'A toolkit for working with videos of FIRST Tech Challenge events using the ftc_event library.'
  spec.description   = spec.summary
  spec.homepage      = 'http://github.com/jeremycole/ftc_video'
  spec.license       = 'MIT'

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files         = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_development_dependency 'bundler', '~> 2.0'
  spec.add_development_dependency 'rake', '~> 13.0'
  spec.add_development_dependency 'rspec', '~> 3.0'
  spec.add_development_dependency 'rubocop', '~> 1.8'

  spec.add_dependency 'ftc_event', '~> 0.1'
  spec.add_dependency 'streamio-ffmpeg', '~> 3.0'
end
