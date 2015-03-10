source "http://rubygems.org"

def location_for(place, fake_version = nil)
  mdata = /^(git:[^#]*)#(.*)/.match(place)
  if mdata
    [fake_version, { :git => mdata[1], :branch => mdata[2], :require => false }].compact
  elsif place =~ /^file:\/\/(.*)/
    ['>= 0', { :path => File.expand_path(mdata[1]), :require => false }]
  else
    [place, { :require => false }]
  end
end

group :development, :test do
  gem 'rake'
  gem 'puppetlabs-stdlib', '1.0.0', :github => 'puppetlabs/puppetlabs-stdlib', :tag => '2.3.0'
  gem 'rspec', "~> 2.11.0", :require => false
  gem 'mocha', "~> 0.10.5", :require => false
  gem 'puppetlabs_spec_helper', :require => false
  gem 'rspec-puppet', :require => false
  gem 'facter', :require => false
  gem 'puppet', :require => false
end


