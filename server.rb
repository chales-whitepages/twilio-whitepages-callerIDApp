require 'rubygems'
require 'sinatra'
require 'twilio-ruby'
require 'httparty'
require 'pusher'

disable :protection

# put your default Twilio Client name here, for when a phone number isn't given
default_client = "hales"
# Add a Twilio phone number or number verified with Twilio as the caller ID
caller_id   = ENV['twilio_caller_id']
account_sid = ENV['twilio_account_sid']
auth_token  = ENV['twilio_auth_token']
appsid      = ENV['twilio_app_id']

# Setting up the web socket client
pusher_client = Pusher::Client.new(
  app_id: ENV['pusher_app_id'],
  key: ENV['pusher_key'],
  secret: ENV['pusher_secret'],
  encrypted: true
)

get '/' do
    client_name = params[:client]
    if client_name.nil?
        client_name = default_client
    end

    capability = Twilio::Util::Capability.new account_sid, auth_token
    # Create an application sid at twilio.com/user/account/apps and use it here/above
    capability.allow_client_outgoing appsid
    capability.allow_client_incoming client_name
    token = capability.generate
    erb :index, :locals => {:token => token, :client_name => client_name, :caller_id=> caller_id}
end

post '/dial' do
    #determine if call is inbound
    number = params[:PhoneNumber]

    response = Twilio::TwiML::Response.new do |r|
        # Should be your Twilio Number or a verified Caller ID
        r.Dial :callerId => caller_id do |d|
            # Test to see if the PhoneNumber is a number, or a Client ID. In
            # this case, we detect a Client ID by the presence of non-numbers
            # in the PhoneNumber parameter.
            if /^[\d\+\-\(\) ]+$/.match(number)
                d.Number(CGI::escapeHTML number)
            else
                d.Client number
            end
        end
    end
    response.text
end

#this will be called from a Twilio voice URL
#for inbound calls, dial the default_client
post '/inbound' do

    from = params[:From]
    addOnData = params[:AddOns]
    # Sending the add on data through the web socket
    pusher_client.trigger('twilio_channel', 'my_event', { message: addOnData })
    # Dials the default_client
    response = Twilio::TwiML::Response.new do |r|
        # Should be your Twilio Number or a verified Caller ID
        r.Dial :callerId => from do |d|
            d.Client default_client
        end
    end
    response.text
end
