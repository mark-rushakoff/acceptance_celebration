require 'sinatra'
require 'sinatra-websocket'
require 'haml'
require 'json/pure'

set :server, 'thin'
set :sockets, []

set :haml, format: :html5

CASH_SOUND = {sound: 'cash'}.to_json.freeze
BREAK_GLASS_SOUND = {sound: 'break_glass'}.to_json.freeze

EM.error_handler do |e|
  puts 'Oops, I had an accident'
  puts e.message
  puts
  puts e.backtrace
end

def send_to_all_sockets(message)
  EM.next_tick do
    settings.sockets.each do |socket|
      socket.send(message)
    end
  end
end

def notify_changes(changes)
  changes.each do |change|
    new_current_state = change.fetch('new_values', {}).fetch('current_state', nil)
    if new_current_state == 'accepted'
      send_to_all_sockets(CASH_SOUND.dup)
    elsif new_current_state == 'rejected'
      send_to_all_sockets(BREAK_GLASS_SOUND.dup)
    end
  end
end

get '/' do
  if request.websocket?
    request.websocket do |ws|
      ws.onopen do
        settings.sockets << ws
      end
      ws.onclose do
        warn("websocket closed")
        settings.sockets.delete(ws)
      end
    end
  else
    haml :index
  end
end

# try: curl -H "Content-Type: application/json" --data @fixtures/story_accepted.json http://localhost:4567/tracker
# try: curl -H "Content-Type: application/json" --data @fixtures/story_rejected_with_comment.json http://localhost:4567/tracker
post '/tracker' do
  p :start
  tracker_data = JSON.parse(request.body.read)

  kind = tracker_data['kind']
  halt(200, 'not a story update') unless kind == 'story_update_activity'

  notify_changes(tracker_data.fetch('changes', []))
  'Thank you for the changes.'
end

# try: curl -X POST --data "sound=bell" http://127.0.0.1:4567/debug
post '/debug' do
  settings.sockets.each do |socket|
    hash = {
      sound: params[:sound]
    }.to_json

    send_to_all_sockets(hash)
  end

  'Successfully debugged'
end
