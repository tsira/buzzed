require 'rubygems'
require 'bundler'
require "sinatra"
require "sinatra/reloader" if development?
require 'dotenv'
require 'twilio-ruby'
require 'slackbotsy'
require 'open-uri'
require "redis"

Dotenv.load

Bundler.require

config = {
  'channel'          => '#launchpad-lab',
  'name'             => 'buzzer',
  'incoming_webhook' => ENV['INCOMING_WEBHOOK'],
  'outgoing_token'   => ENV['OUTGOING_TOKEN']
}

redis = Redis.new(:url => ENV['REDIS_URL'])

bot = Slackbotsy::Bot.new(config) do

  hear /^.open$/i do
    redis.set("door_status", "open")
    redis.expire("door_status", 30)
    "Buzzed!"
  end

  hear /^.stayopen$/i do
    redis.set("door_status", "auto")
    redis.expire("door_status", 3600)
    "The door will automatically buzz in for an hour."
  end

  hear /^.close$/i do
    redis.expire("door_status", 0)
    "The door has been closed and will not automatically buzz in."
  end

end

post '/' do
  if redis.get("door_status") == "auto"
    bot.post(channel: '#launchpad-lab', username: 'buzzer', icon_emoji: ':door:', text: "Someone has been buzzed in.")
    content_type 'text/xml'
    Twilio::TwiML::Response.new do |r|
      r.Say 'Hello, and welcome to Launch Pad Lab.'
      r.Play digits: 'wwww6'
    end.text
  else
    bot.post(channel: '#launchpad-lab', username: 'buzzer', icon_emoji: ':door:', text: "Someone is at the front door.\nType *.open* to let them in.")
    redirect to('/say-hello')
  end
end

get '/say-hello' do
  content_type 'text/xml'
  Twilio::TwiML::Response.new do |r|
    r.Say 'Hello, and welcome to Launch Pad Lab.'
    r.Play '/such_great_heights.mp3'
  end.text
end

post '/door-status' do
  bot.handle_item(params)
end

post '/buzz-door' do
  client = Twilio::REST::Client.new ENV['TWILIO_SID'], ENV['TWILIO_TOKEN']
  calls = client.account.calls.list({ :status => 'in-progress' })
  if calls.any?
    current_call = client.account.calls.get(calls.first.sid)
    current_call.update(:url => "https://buzzed-app.herokuapp.com/buzz.xml", :method => "GET")
  end
end

get '/stay-awake' do
  "Wake Up!"
end
