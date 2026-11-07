require 'swagger_helper'

describe 'Rack::Attack' do
  include ActiveSupport::Testing::TimeHelpers

  around do |example|
    store = Rack::Attack.cache.store
    Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new
    Rack::Attack.enabled = true
    freeze_time { example.run }
  ensure
    Rack::Attack.enabled = false
    Rack::Attack.cache.store = store
  end

  def sign_in_request(email: 'user@example.com', ip: '8.8.8.8', path: '/api/v1/auth/sign_in', headers: {})
    post path, params: { user: { email:, password: 'wrong-password' } }, as: :json, env: { REMOTE_ADDR: ip }, headers:
  end

  describe 'POST /api/v1/auth/sign_in' do
    it 'throttles by IP and responds with a JSON error' do
      5.times { |i| sign_in_request(email: "user#{i}@example.com") }
      expect(response).to have_http_status(:unauthorized)

      sign_in_request(email: 'other@example.com')

      expect(response).to have_http_status(:too_many_requests)
      expect(response.media_type).to eq('application/json')
      expect(response.headers['retry-after'].to_i).to be_between(1, 60)
      expect(json_response).to eq('message' => 'Too many requests, please try again later', 'status' => 429)
    end

    it 'throttles by email across IPs, ignoring case and surrounding spaces' do
      5.times { |i| sign_in_request(ip: "8.8.8.#{i}") }

      sign_in_request(email: ' USER@example.com ', ip: '8.8.4.4')

      expect(response).to have_http_status(:too_many_requests)
    end

    it 'does not affect other clients' do
      6.times { sign_in_request }

      sign_in_request(email: 'other@example.com', ip: '8.8.4.4')

      expect(response).to have_http_status(:unauthorized)
    end

    it 'allows requests again in the next period' do
      6.times { sign_in_request }

      travel 1.minute
      sign_in_request

      expect(response).to have_http_status(:unauthorized)
    end

    it 'counts equivalent paths together' do
      sign_in_request(email: 'a@example.com', path: '/api/v1/auth/sign_in.json')
      sign_in_request(email: 'b@example.com', path: '/api/v1/auth/sign_in/')
      3.times { |i| sign_in_request(email: "c#{i}@example.com") }

      sign_in_request(email: 'd@example.com')

      expect(response).to have_http_status(:too_many_requests)
    end

    it 'can not be bypassed by spoofing X-Forwarded-For behind the proxy' do
      5.times do |i|
        sign_in_request(email: "user#{i}@example.com", ip: '172.18.0.2', headers: { 'X-Forwarded-For' => "1.1.1.#{i}, 8.8.8.8" })
      end

      sign_in_request(email: 'other@example.com', ip: '172.18.0.2', headers: { 'X-Forwarded-For' => '1.1.1.9, 8.8.8.8' })

      expect(response).to have_http_status(:too_many_requests)
    end

    it 'can not be bypassed with a client-supplied Forwarded header' do
      5.times do |i|
        sign_in_request(email: "user#{i}@example.com", ip: '10.0.1.5', headers: { 'X-Forwarded-For' => '8.8.8.8', 'Forwarded' => "for=1.1.1.#{i}" })
      end

      sign_in_request(email: 'other@example.com', ip: '10.0.1.5', headers: { 'X-Forwarded-For' => '8.8.8.8', 'Forwarded' => 'for=1.1.1.9' })

      expect(response).to have_http_status(:too_many_requests)
    end

    [
      ['malformed JSON', '{"user":', { 'CONTENT_TYPE' => 'application/json' }],
      ['a malformed form body', 'user[email]=%', { 'CONTENT_TYPE' => 'application/x-www-form-urlencoded' }],
      ['a non-object user', '{"user":"a"}', { 'CONTENT_TYPE' => 'application/json' }],
      ['a non-string email', '{"user":{"email":{"a":1}}}', { 'CONTENT_TYPE' => 'application/json' }]
    ].each do |name, body, headers|
      it "does not raise from the throttle on #{name}" do
        app = Rack::Attack.new(->(_env) { [200, {}, ['ok']] })
        result = Rack::MockRequest.new(app).post('/api/v1/auth/sign_in', headers.merge(input: body))

        expect(result.status).to eq(200)
      end
    end
  end

  {
    '/api/v1/auth/password' => 'password',
    '/api/v1/auth/confirmation' => 'confirmation'
  }.each do |path, name|
    describe "POST #{path}" do
      it "throttles #{name} emails by address" do
        3.times { |i| post path, params: { user: { email: 'user@example.com' } }, as: :json, env: { REMOTE_ADDR: "8.8.8.#{i}" } }
        expect(response).to have_http_status(:ok)

        post path, params: { user: { email: 'user@example.com' } }, as: :json, env: { REMOTE_ADDR: '8.8.4.4' }

        expect(response).to have_http_status(:too_many_requests)
      end

      it "throttles #{name} emails by IP" do
        5.times { |i| post path, params: { user: { email: "user#{i}@example.com" } }, as: :json }
        expect(response).to have_http_status(:ok)

        post path, params: { user: { email: 'other@example.com' } }, as: :json

        expect(response).to have_http_status(:too_many_requests)
      end
    end
  end

  describe 'POST /api/v1/auth/sign_up' do
    it 'throttles by IP' do
      params = { user: { email: 'invalid' } }
      10.times { post '/api/v1/auth/sign_up', params:, as: :json }
      expect(response).to have_http_status(:unprocessable_content)

      post '/api/v1/auth/sign_up', params:, as: :json

      expect(response).to have_http_status(:too_many_requests)
    end
  end

  describe 'POST /api/v1/blobs' do
    it 'throttles by IP' do
      30.times { post '/api/v1/blobs' }
      expect(response).to have_http_status(:unauthorized)

      post '/api/v1/blobs'

      expect(response).to have_http_status(:too_many_requests)
    end
  end

  describe 'other requests' do
    it 'throttles the whole API by IP' do
      300.times { get '/api/v1/auth/profile' }
      expect(response).to have_http_status(:unauthorized)

      get '/api/v1/auth/profile'

      expect(response).to have_http_status(:too_many_requests)
    end

    it 'does not throttle the health check' do
      301.times { get '/up' }

      expect(response).to have_http_status(:ok)
    end
  end
end
