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

def notify_changes(changes, primary_resources, project_name)
  changes.each do |change|
    new_current_state = change.fetch('new_values', {}).fetch('current_state', nil)

    resource = primary_resources.find {|r| r['id'] == change['id'] }
    next if resource.nil?

    story_url = resource['url']
    story_name = resource['name']
    result = {
      storyLink: story_url,
      storyText: "#{project_name}: #{story_name}",
      newState: new_current_state,
    }

    if new_current_state == 'accepted'
      result.merge!(sound: 'cash')
    elsif new_current_state == 'rejected'
      result.merge!(sound: 'break_glass')
    else
      return
    end

    send_to_all_sockets(result.to_json)
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
  tracker_data = JSON.parse(request.body.read)

  kind = tracker_data['kind']
  halt(200, 'not a story update') unless kind == 'story_update_activity'

  changes = tracker_data.fetch('changes', [])
  primary_resources = tracker_data.fetch('primary_resources', [])
  project_name = tracker_data.fetch('project', {})['name']

  notify_changes(changes, primary_resources, project_name)
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
