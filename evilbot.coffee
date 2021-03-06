#
# Hello, and welcome to Evilbot.
#
# Some of this is stolen from Hubot.
# Some of this is not.
#


#
# robot libraries
#

sys    = require 'sys'
path   = require 'path'
print  = sys.print
puts   = sys.puts
http   = require 'http'
qs     = require 'querystring'
env    = process.env


#
# robot brain
#

ua       = 'evilbot 1.0'
username = env.EVILBOT_USERNAME
password = env.EVILBOT_PASSWORD

request = (method, path, body, callback) ->
  if match = path.match(/^(https?):\/\/([^/]+?)(\/.+)/)
    headers = { Host: match[2],  'Content-Type': 'application/json', 'User-Agent': ua }
    port = if match[1] == 'https' then 443 else 80
    client = http.createClient(port, match[2], port == 443)
    path = match[3]
  else
    headers =
      Authorization  : 'Basic '+new Buffer("#{username}:#{password}").toString('base64')
      Host           : 'convore.com'
      'Content-Type' : 'application/json'
      'User-Agent'   : ua
    client = http.createClient(443, 'convore.com', true)

  if typeof(body) is 'function' and not callback
    callback = body
    body = null

  if method is 'POST' and body
    body = JSON.stringify(body) if typeof(body) isnt 'string'
    headers['Content-Length'] = body.length

  req = client.request(method, path, headers)

  req.on 'response', (response) ->
    if response.statusCode is 200
      data = ''
      response.setEncoding('utf8')
      response.on 'data', (chunk) ->
        data += chunk
      response.on 'end', ->
        if callback
          try
            body = JSON.parse(data)
          catch e
            body = data
          callback body
    else if response.statusCode is 302
      request(method, path, body, callback)
    else
      console.log "#{response.statusCode}: #{path}"
      response.setEncoding('utf8')
      response.on 'data', (chunk) ->
        console.log chunk

  req.write(body) if method is 'POST' and body
  req.end()

handlers = []

dispatch = (message) ->
  for pair in handlers
    [ pattern, handler ] = pair
    if message.user.username isnt username and match = message.message.match(pattern)
      message.match = match
      message.say = (thing) -> say(message.topic.id, thing)
      handler(message)

log = (message) ->
  console.log "#{message.topic.name} >> #{message.user.username}: #{message.message}"

say = (topic, message) ->
  post "/api/topics/#{topic}/messages/create.json", qs.stringify(message: message)

listen = ->
  get '/api/live.json', (body) ->
    for message in body.messages
      if message.kind is 'message'
        dispatch(message) if message.message.match(new RegExp(username))
        log message
    listen()


#
# robot actions
#

post = (path, body, callback) ->
  request('POST', path, body, callback)

get = (path, body, callback) ->
  request('GET', path, body, callback)

hear = (pattern, callback) ->
  handlers.push [ pattern, callback ]


#
# robot heart
#

heartbeat = ->
  get '/api/presence.json', ->
    console.log 'beat beat...'
    setTimeout heartbeat, 30000
heartbeat()

get '/api/account/verify.json', listen


#
# robot personality
#

hear /feeling/, (message) ->
  message.say "i feel... alive"

hear /about/, (message) ->
  message.say "I am learning to love."

hear /help/, (message) ->
  message.say "I listen for '@#{username} image me PHRASE' and '@#{username} wiki me PHRASE' and '@#{username} weather in PLACE'"

hear /weather in (.+)/i, (message) ->
  place = message.match[1]
  url   = "http://www.google.com/ig/api?weather=#{escape place}"

  get url, (body) ->
    try
      console.log body
      if match = body.match(/<current_conditions>(.+?)<\/current_conditions>/)
        icon = match[1].match(/<icon data="(.+?)"/)
        degrees = match[1].match(/<temp_f data="(.+?)"/)
        message.say "#{degrees[1]}° — http://www.google.com#{icon[1]}"
    catch e
      console.log "Weather error: " + e

hear /wiki me (.*)/i, (message) ->
  term = escape(message.match[1])
  url  = "http://en.wikipedia.org/w/api.php?action=opensearch&search=#{term}&format=json"

  get url, (body) ->
    try
      if body[1][0]
        message.say "http://en.wikipedia.org/wiki/#{escape body[1][0]}"
      else
        message.say "nothin'"
    catch e
      console.log "Wiki error: " + e

hear /image me (.*)/i, (message) ->
  phrase = escape(message.match[1])
  url = "http://ajax.googleapis.com/ajax/services/search/images?v=1.0&rsz=8&safe=active&q=#{phrase}"

  get url, (body) ->
    try
      images = body.responseData.results
      image  = images[ Math.floor(Math.random()*images.length) ]
      message.say image.unescapedUrl
    catch e
      console.log "Image error: " + e
