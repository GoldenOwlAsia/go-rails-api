require 'rails_helper'

describe DeviseJwt::PurgeExpiredJwtsJob do
  it_behaves_like 'enqueues_job_correctly', :low

  describe '#perform' do
    let!(:user) { create(:user) }
    let!(:expired_jwt) { user.on_jwt_dispatch(:token, { 'exp' => (Time.current - 1.hour).to_i, 'jti' => SecureRandom.hex }) }
    let!(:valid_jwt) { user.on_jwt_dispatch(:token, { 'exp' => (Time.current + 1.hour).to_i, 'jti' => SecureRandom.hex }) }

    it 'deletes expired jwts' do
      described_class.perform_now

      expect(AllowlistedJwt.exists?(expired_jwt.id)).to be(false)
      expect(AllowlistedJwt.exists?(valid_jwt.id)).to be(true)
    end
  end
end
