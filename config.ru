require 'rubygems'
require 'rack'
require 'omniauth/cas'

class InsistOnAuth
  def initialize(app, provider)
    @app = app
    @provider = provider
  end

  def call(env)
    if env["rack.session"] and env["rack.session"]["user"]
      @app.call(env)
    else
      request = Rack::Request.new(env)
      return_url = request.url
      [302, {'Content-Type' => 'text', 'Location' => "/auth/#{@provider}?return_url=#{return_url}"}, ['302 Found']]
    end
  end
end

app = Rack::Builder.new do
  use Rack::Session::Cookie, key: 'omniauth-test', secret: ENV["SESSION_COOKIE_SECRET"] || "insecure"
  use OmniAuth::Builder do
    provider :cas, url: 'https://login.konsoleh.co.za/cas'
  end
  map "/auth/cas/callback" do
    run ->(env) do
      if env["omniauth.auth"]
        env["rack.session"]["user"] = env["omniauth.auth"]["uid"]
        request = Rack::Request.new(env)
        return_url = request.params["return_url"] or "/"
        [302, {'Content-Type' => 'text/plain', 'Location' => return_url}, ['302 Found']]
      else
        [401, {'Content-Type' => 'text/plain'}, ['401 Not Authorized']]
      end
    end
  end
  map "/auth/failure" do
    run ->(env) do
      request = Rack::Request.new(env)
      [401, {'Content-Type' => 'text/plain'}, ["401 Not Authorized: #{request.params["message"]}"]]
    end
  end

  map "/hello" do
    use InsistOnAuth, :cas
    run ->(env) { [200, {'Content-Type' => 'text/html'}, ['<html><body><p>Hello, world!</p></body></html>']] }
  end

  map "/" do
    run ->(env) do
      [200, {'Content-Type' => 'text/html'}, [
        %q{<html><body><p>This page is public. The password-protected stuff is <a href="/hello">here</a>.</p></body></html>}
      ]]
    end
  end
end

run app
