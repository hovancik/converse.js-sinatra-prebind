require 'sinatra'
require 'pry' # for debugging
require 'json'
require 'dotenv'
require 'xmpp4r/httpbinding/client'
require 'rack/ssl'

# main sinatra app
class App < Sinatra::Base
  Dotenv.load
  enable :sessions
  set :session_secret, ENV['SESSION_SECRET']
  use Rack::MethodOverride
  use Rack::SSL if ENV["USE_SSL"]==1
  configure { set :server, :puma }

  get '/' do
    if session[:rid]
      erb :chat
    else
      erb :index
    end
  end

  get '/prebind' do
    content_type :json
    if session[:jid] && session[:sid] && session[:rid]
      {
        jid: session[:jid],
        sid: session[:sid],
        rid: session[:rid],
        bosh_service_url: session[:bosh_service_url]
      }.to_json
    else
      {}
    end
  end

  post '/login' do
    begin
      have_params = params[:user] != '' && params[:password] != ''
      raise Jabber::ClientAuthenticationFailure unless have_params
      client = Jabber::HTTPBinding::Client.new(params[:user])
      client.connect(ENV['BOSH_SERVICE_URL'])
      client.auth(params[:password])
      jid = client.instance_variable_get('@jid')
      session[:jid] = "#{jid.node}@#{jid.domain}/#{jid.resource}"
      session[:sid] = client.instance_variable_get('@http_sid')
      session[:rid] = client.instance_variable_get('@http_rid')
      session[:bosh_service_url] = ENV['BOSH_SERVICE_URL']
    rescue Jabber::ClientAuthenticationFailure
      clear_session
    end
    redirect to('/')
  end

  delete '/logout' do
    clear_session
    redirect to('/')
  end

  private

  def clear_session
    session[:jid] = nil
    session[:sid] = nil
    session[:rid] = nil
    session[:bosh_service_url] = nil
  end
end
