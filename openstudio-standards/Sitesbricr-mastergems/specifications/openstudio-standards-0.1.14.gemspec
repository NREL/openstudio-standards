# -*- encoding: utf-8 -*-
# stub: openstudio-standards 0.1.14 ruby lib

Gem::Specification.new do |s|
  s.name = "openstudio-standards"
  s.version = "0.1.14"

  s.required_rubygems_version = Gem::Requirement.new(">= 1.3.6") if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib"]
  s.authors = ["Andrew Parker", "Yixing Chen", "Mark Adams", "Kaiyu Sun", "Mini Maholtra", "David Goldwasser", "Phylroy Lopez", "Maria Mottillo", "Kamel Haddad", "Julien Marrec", "Matt Leach", "Matt Steen", "Eric Ringold", "Daniel Macumber"]
  s.date = "2017-07-03"
  s.description = "Creates DOE Prototype building models and transforms proposed models to baseline models for energy codes like ASHRAE 90.1 and the Canadian NECB."
  s.email = ["andrew.parker@nrel.gov"]
  s.homepage = "http://openstudio.net"
  s.licenses = ["LGPL"]
  s.required_ruby_version = Gem::Requirement.new(">= 2.0.0")
  s.rubygems_version = "2.4.5.2"
  s.summary = "Creates DOE Prototype building models and transforms proposed OpenStudio models to baseline OpenStudio models."

  s.installed_by_version = "2.4.5.2" if s.respond_to? :installed_by_version

  if s.respond_to? :specification_version then
    s.specification_version = 4

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_development_dependency(%q<nokogiri>, ["<= 1.6.8.1"])
      s.add_development_dependency(%q<bundler>, ["~> 1.9"])
      s.add_development_dependency(%q<rake>, ["~> 10.0"])
      s.add_development_dependency(%q<yard>, ["~> 0.8"])
      s.add_development_dependency(%q<rubocop>, ["~> 0.42"])
      s.add_development_dependency(%q<rubocop-checkstyle_formatter>, ["~> 0.1.1"])
      s.add_development_dependency(%q<minitest-ci>, [">= 0"])
      s.add_development_dependency(%q<minitest-reporters>, [">= 0"])
      s.add_development_dependency(%q<rubyXL>, ["= 3.3.8"])
      s.add_development_dependency(%q<activesupport>, ["= 4.2.5"])
      s.add_development_dependency(%q<google-api-client>, ["= 0.8.6"])
      s.add_development_dependency(%q<codecov>, [">= 0"])
    else
      s.add_dependency(%q<nokogiri>, ["<= 1.6.8.1"])
      s.add_dependency(%q<bundler>, ["~> 1.9"])
      s.add_dependency(%q<rake>, ["~> 10.0"])
      s.add_dependency(%q<yard>, ["~> 0.8"])
      s.add_dependency(%q<rubocop>, ["~> 0.42"])
      s.add_dependency(%q<rubocop-checkstyle_formatter>, ["~> 0.1.1"])
      s.add_dependency(%q<minitest-ci>, [">= 0"])
      s.add_dependency(%q<minitest-reporters>, [">= 0"])
      s.add_dependency(%q<rubyXL>, ["= 3.3.8"])
      s.add_dependency(%q<activesupport>, ["= 4.2.5"])
      s.add_dependency(%q<google-api-client>, ["= 0.8.6"])
      s.add_dependency(%q<codecov>, [">= 0"])
    end
  else
    s.add_dependency(%q<nokogiri>, ["<= 1.6.8.1"])
    s.add_dependency(%q<bundler>, ["~> 1.9"])
    s.add_dependency(%q<rake>, ["~> 10.0"])
    s.add_dependency(%q<yard>, ["~> 0.8"])
    s.add_dependency(%q<rubocop>, ["~> 0.42"])
    s.add_dependency(%q<rubocop-checkstyle_formatter>, ["~> 0.1.1"])
    s.add_dependency(%q<minitest-ci>, [">= 0"])
    s.add_dependency(%q<minitest-reporters>, [">= 0"])
    s.add_dependency(%q<rubyXL>, ["= 3.3.8"])
    s.add_dependency(%q<activesupport>, ["= 4.2.5"])
    s.add_dependency(%q<google-api-client>, ["= 0.8.6"])
    s.add_dependency(%q<codecov>, [">= 0"])
  end
end
