require 'simplecov'
SimpleCov.start do
  skip 'config/'
  skip 'spec/'
  group 'Controllers', 'app/controllers'
  group 'Decorators', 'app/decorators'
  group 'Jobs', 'app/jobs'
  group 'Mailers', 'app/mailers'
  group 'Models', 'app/models'
  group 'Operations', 'app/operations'
  group 'Policies', 'app/policies'
  group 'Queries', 'app/queries'
  group 'Serializers', 'app/serializers'
end

require 'spec_helper'
ENV['RAILS_ENV'] ||= 'test'
require File.expand_path('../config/environment', __dir__)
abort('The Rails environment is running in production mode!') if Rails.env.production?
require 'rspec/rails'
require 'faker'

Dir[Rails.root.join('spec/supports/**/*.rb')].each { |f| require f }

begin
  ActiveRecord::Migration.maintain_test_schema!
rescue ActiveRecord::PendingMigrationError => e
  abort(e.to_s.strip)
end

RSpec.configure do |config|
  config.fixture_paths = ["#{Rails.root}/spec/fixtures"]
  config.use_transactional_fixtures = true
  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!
end
