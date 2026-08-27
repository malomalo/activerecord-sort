require_relative "lib/active_record/sort/version"

Gem::Specification.new do |spec|
  spec.name         = "activerecord-sort"
  spec.version      = ActiveRecord::Sort::VERSION
  spec.authors      = ["Jon Bracy"]
  spec.email        = ["jonbracy@gmail.com"]
  spec.summary      = %q{A safe way to accept user parameters and order against your ActiveRecord Models}
  spec.description  = %q{Adds a #sort query method to ActiveRecord that turns whitelisted user-supplied parameters into ORDER BY clauses -- ordering by columns or associations, ascending/descending, with NULLS handling and random ordering -- without exposing you to SQL injection.}
  spec.homepage     = "https://github.com/malomalo/activerecord-sort"
  spec.licenses     = ['MIT']

  spec.metadata = {
    "source_code_uri"       => spec.homepage,
    "changelog_uri"         => "#{spec.homepage}/blob/master/CHANGELOG.md",
    "rubygems_mfa_required" => "true",
  }

  spec.required_ruby_version = '>= 3.3'

  spec.files        = `git ls-files -- lib ext CHANGELOG.md LICENSE README.md`.split("\n")
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency 'activerecord', '>= 8.0.0', '< 9.0'
  spec.add_runtime_dependency 'arel-extensions', '>= 9.0.0'

  spec.add_development_dependency 'pg'
  spec.add_development_dependency "rake"
  spec.add_development_dependency 'minitest'
  spec.add_development_dependency 'minitest-reporters'
  spec.add_development_dependency "simplecov"
  spec.add_development_dependency "factory_bot"
  spec.add_development_dependency "faker"
  spec.add_development_dependency "sunstone", '>= 7.0.0'
  spec.add_development_dependency "webmock"
end
