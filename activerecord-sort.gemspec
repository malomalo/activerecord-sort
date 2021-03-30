require File.expand_path("../lib/active_record/sort/version", __FILE__)

Gem::Specification.new do |spec|
  spec.name           = "activerecord-sort"
  spec.version        = ActiveRecord::Sort::VERSION
  spec.licenses       = ['MIT']
  spec.authors        = ["Jon Bracy"]
  spec.email          = ["jonbracy@gmail.com"]
  spec.homepage       = "https://github.com/malomalo/activerecord-sort"
  spec.description    = %q{A safe way to accept user parameters and order against your ActiveRecord Models}
  spec.summary        = %q{A safe way to accept user parameters and order against your ActiveRecord Models}

  spec.extra_rdoc_files = %w(README.md)
  spec.rdoc_options.concat ['--main', 'README.md']

  spec.files          = Dir["LICENSE", "README.rdoc", "lib/**/*", "ext/**/*"]
  spec.require_paths  = ["lib"]

  spec.add_runtime_dependency 'activerecord', '>= 6.1.0'
  spec.add_runtime_dependency 'arel-extensions', '>= 6.1.0'

  spec.add_development_dependency 'pg'
  spec.add_development_dependency "bundler"
  spec.add_development_dependency "rake"
  spec.add_development_dependency 'minitest'
  spec.add_development_dependency 'minitest-reporters'
  spec.add_development_dependency "simplecov"
  spec.add_development_dependency "factory_bot"
  spec.add_development_dependency "faker"
  spec.add_development_dependency "sunstone", '>= 6.1.0.2'
  spec.add_development_dependency "webmock"
  # spec.add_development_dependency 'sdoc',                '~> 0.4'
  # spec.add_development_dependency 'sdoc-templates-42floors', '~> 0.3'
end
