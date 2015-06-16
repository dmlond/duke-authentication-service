class AuthenticationController < ApplicationController
  def authenticate
    [:client_id, :state].each do |required_param|
      unless params.has_key?(required_param)
        render plain: 'invalid_request', status: 401, layout: false
        return
      end
    end
    @consumer = Consumer.where(uuid: params[:client_id]).first
    if @consumer
      session[:client_id] = params[:client_id]
      session[:state] = params[:state]
      if session[:scope]
        session[:scope] = params[:scope]
      end
      session[:respose_type] = 'token'
      redirect_to shibboleth_login_url
    else
      render plain: 'invalid_request', status: 401, layout: false
      return
    end
  end

  def handle_shibboleth
    session[:uid] = request.env['omniauth.auth'][:uid]
    session[:display_name] = request.env['omniauth.auth'][:info][:name]
    session[:mail] = request.env['omniauth.auth'][:info][:mail]
    @user = User.where(uid: session[:uid]).first
    if @user
      redirect_to_consumer
    else
      redirect_to authorize_url
    end
  end

  def authorize
    @user = User.new(uid: session[:uid])
  end

  def process_authorization
    if params[:submitted] == 'allow'
      @user = User.create(uid: session[:uid])
    end
    redirect_to_consumer
  end

  private

  def redirect_to_consumer
    consumer = Consumer.where(uuid: session[:client_id]).first
    if @user
      @token = @user.token(
        client_id: consumer.uuid,
        display_name: session[:display_name],
        mail: session[:mail],
        scope: session[:scope] || Rails.application.config.default_scope
      )
      access_token = consumer.signed_token({
        access_token: @token
      })
      token_ttl = $redis.ttl(@token)
      params = {
        access_token: access_token,
        token_type: 'Bearer',
        state: session[:state],
        expires_in: token_ttl,
        scope: session[:scope] || Rails.application.config.default_scope
      }
    else
      params = {
        error: 'access_denied',
        state: session[:state]
      }
    end
    redirect_to(consumer.redirect_uri+'#'+params.to_query)
  end
end