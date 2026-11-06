# The ALB appends the client IP to X-Forwarded-For but passes a client-supplied
# Forwarded header through, and Rack would otherwise prefer it when resolving req.ip.
Rack::Request.forwarded_priority = [:x_forwarded]

# Counters live in Redis so they are shared between instances. When Redis is
# unreachable the cache store swallows the error and requests are let through.
Rack::Attack.cache.store = ActiveSupport::Cache::RedisCacheStore.new(
  url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/1')
)
Rack::Attack.enabled = !Rails.env.test?

post_to = lambda do |req, path|
  req.post? && req.path.match?(%r{\A/api/v1/#{path}(\.\w+)?\z})
end

# Rack does not parse JSON bodies, so read them the way the controllers will.
# The address is hashed to keep it out of Redis.
hashed_email = lambda do |req|
  user = ActionDispatch::Request.new(req.env).request_parameters['user']
  email = user['email'] if user.is_a?(Hash)
  Digest::SHA256.hexdigest(email.strip.downcase) if email.is_a?(String) && email.present?
rescue ActionDispatch::Http::Parameters::ParseError, ActionController::BadRequest
  nil
end

Rack::Attack.throttle('api/ip', limit: 300, period: 1.minute) do |req|
  req.ip if req.path.start_with?('/api/')
end

Rack::Attack.throttle('sign_in/ip', limit: 5, period: 1.minute) do |req|
  req.ip if post_to.call(req, 'auth/sign_in')
end

Rack::Attack.throttle('sign_in/email', limit: 5, period: 1.minute) do |req|
  hashed_email.call(req) if post_to.call(req, 'auth/sign_in')
end

Rack::Attack.throttle('sign_up/ip', limit: 10, period: 1.hour) do |req|
  req.ip if post_to.call(req, 'auth/sign_up')
end

%w[password confirmation].each do |resource|
  Rack::Attack.throttle("#{resource}/ip", limit: 5, period: 1.hour) do |req|
    req.ip if post_to.call(req, "auth/#{resource}")
  end

  Rack::Attack.throttle("#{resource}/email", limit: 3, period: 1.hour) do |req|
    hashed_email.call(req) if post_to.call(req, "auth/#{resource}")
  end
end

Rack::Attack.throttle('blobs/ip', limit: 30, period: 1.minute) do |req|
  req.ip if post_to.call(req, 'blobs')
end

Rack::Attack.throttled_responder = lambda do |req|
  match_data = req.env['rack.attack.match_data']
  retry_after = match_data[:period] - (match_data[:epoch_time] % match_data[:period])

  [429, { 'content-type' => 'application/json', 'retry-after' => retry_after.to_s }, [APIError::TooManyRequestsError.new.to_json]]
end

ActiveSupport::Notifications.subscribe('throttle.rack_attack') do |_name, _start, _finish, _id, payload|
  req = payload[:request]
  Rails.logger.warn("[rack-attack] throttled #{req.env['rack.attack.matched']} #{req.request_method} #{req.path} ip=#{req.ip}")
end
