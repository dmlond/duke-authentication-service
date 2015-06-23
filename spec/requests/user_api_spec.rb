require 'rails_helper'
require 'jwt'

describe DukeAuth::V1::UserAPI do
  let(:json_headers) { { 'Accept' => 'application/json', 'Content-Type' => 'application/json'} }
  let(:consumer) {FactoryGirl.create(:consumer)}
  let (:user) { FactoryGirl.create(:user) }
  let(:display_name) { Faker::Name.name }
  let(:email) { Faker::Internet.email }
  let(:scope) { 'display_name email uid' }
  let(:signed_info) { 
    consumer.signed_token({
      uid: user.uid,
      display_name: display_name,
      email: email,
      service_id: Rails.application.secrets.service_id
    })
  }
  let (:token) { 
    user.token(
      client_id: consumer.uuid,
      display_name: display_name, 
      email: email, 
      scope: scope
    ) 
  }

  describe 'get token_info' do
    it 'should respond with a JSON object that describes the valid token' do
      get "/api/v1/token_info/", {access_token: token}, json_headers
      expect(response.status).to eq(200)
      expect(response.body).to be
      expect(response.body).not_to eq('null')

      response_json = JSON.parse(response.body)
      expect(response_json).to have_key('audience')
      expect(response_json['audience']).to eq(consumer.uuid)
      expect(response_json).to have_key('uid')
      expect(response_json['uid']).to eq(user.uid)
      expect(response_json).to have_key('scope')
      expect(response_json['scope']).to eq(scope)
      expect(response_json).to have_key('signed_info')
      expect(response_json['signed_info']).to eq(signed_info)
      expect(response_json).to have_key('expires_in')
      expected_ttl = $redis.ttl(token)
      expect(expected_ttl).not_to eq(-1)
      expect(expected_ttl).to be > 0
      expect(response_json['expires_in']).to eq(expected_ttl)
    end

    it 'should respond with an error for an expired token' do
      $redis.del(token)
      expect($redis.exists(token)).not_to be
      expect(User.credentials(token)).to be_nil
      get "/api/v1/token_info/", {access_token: token}, json_headers
      expect(response.status).to eq(400)
      expect(response.body).to be
      expect(response.body).to eq('{"error":"invalid_token"}')
    end
  end #get token_info
end
