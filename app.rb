require 'sinatra'
require 'sinatra-websocket'
require 'haml'
require 'json/pure'

set :server, 'thin'
set :sockets, []

set :haml, format: :html5

def send_to_all_sockets(message)
  EM.next_tick do
    settings.sockets.each do |socket|
      socket.send(message)
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
