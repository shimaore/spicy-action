Authentication Proxy
====================

This is an authentication proxy for CouchDB, using a custom (cookie-session-based) authentication scheme.

This is also a Socket.IO server for external users, allowing the propagation of events to users, and for internal (services) users, allowing the generation of events. In other words this is an event broker.

    run = (cfg) ->
      pkg = require './package.json'
      Cuddly = require 'cuddly'

      zappa = require 'zappajs'

      redis = require 'socket.io-redis'

      auth_required = ->
        if @session.couchdb_token?
          @next()
          return
        @session = null
        @res
          .status 401
          .set 'WWW-Authenticate': "Basic: realm=#{@pkg.name}"
        @json error: 'Not authenticated'
        @res.end()
        return

External (public) service
=========================

      zappa cfg.public_host, cfg.public_port, https:cfg.ssl, ->

        @use morgan:'combined'

        @helper {cfg,pkg}
        @cfg = cfg

        @get '/', ->
          @json
            ok:true
            name:pkg.name
            version:pkg.version
            local:(require './local/package.json').version

        @use 'cookie-parser'

Authentication

        @auth = []

        for auth_name in ['./local/auth','./couchdb-auth']
          auth_module = require auth_name
          @include auth_module  if auth_module.include?
          @auth.push @wrap auth_module.middleware if auth_module.middleware?

Fail if not authenticated.

        @auth.push @wrap auth_required

Express: Store our session in Redis so that we can offload the Socket.IO piece to a different server if needed.

        session_store = (require 'connect-redis') @session
        @use session:
          store: new session_store cfg.redis
          secret: cfg.session_secret
          resave: true
          unset: 'destroy'
          saveUninitialized: true
          cookie:
            maxAge: cfg.session_maxage ? 30*60*1000
            secure: cfg.session_secure ? true

Socket.IO: allow broadcast across multiple Socket.IO servers (through Redis pub/sub).

        @io.adapter redis cfg.redis

Local pub/sub logic.

        @on connection: ->
          @join 'public' # No authentication required
          @emit welcome: {@id,name:pkg.name,version:pkg.version,public:true}

        @on join: ->
          unless @session?.couchdb_username?
            @emit failed: {msg:'You must authenticate first.'}
            return
          @join 'everyone'
          if @session.admin
            @join 'internal'
            @join 'calls'
            @join 'support'
          @emit ready: roles:@session.couchdb_roles

Message towards `nifty-ground`

        @on trace: ->
          if @session.admin
            @broadcast_to 'traces', 'trace', @data

Messages towards `ccnq4-opensips`

        @on location: ->
          if @session.admin
            @broadcast_to 'locations', 'location', @data

        @on locations: ->
          if @session.admin
            @broadcast_to 'locations', 'locations', @data

Inventory

        @on ping: ->
          if @session.admin
            @broadcast_to 'traces', 'ping', @data
            @broadcast_to 'locations', 'ping', @data

CouchDB reverse proxy with embedded authentication.

        @include './public_proxy'

Other local services.

        @include './local/public'

Internal (services): these need to be able to pub/sub and proxy.
====================

      zappa cfg.internal_host, cfg.internal_port, ->

        @use morgan:'combined'

        @helper {cfg,pkg}
        @cfg = cfg

        @use 'cookie-parser'

Authentication

        @auth = []

        for auth_name in ['./couchdb-auth']
          auth_module = require auth_name
          @include auth_module  if auth_module.include?
          @auth.push @wrap auth_module.middleware if auth_module.middleware?

Fail if not authenticated.

        @auth.push @wrap auth_required

Express: Store our session in Redis so that we can offload the Socket.IO piece to a different server if needed.

        session_store = (require 'connect-redis') @session
        @use session:
          store: new session_store cfg.redis
          secret: cfg.session_secret
          resave: true
          unset: 'destroy'
          saveUninitialized: false

Socket.IO: allow broadcast across multiple Socket.IO servers (through Redis pub/sub).

        @io.adapter redis cfg.redis

        @get '/', ->
          @json
            ok:true
            name:pkg.name
            version:pkg.version
            local:(require './local/package.json').version

        @on connection: ->
          @emit welcome: {@id,name:pkg.name,version:pkg.version,public:false}

        @on configure: ->

          for bus in [
            'calls'
            'internal'
            'locations'
            'support'
            'traces'
          ]
            do (bus) =>
              switch @data[bus]
                when true
                  @join bus
                when false
                  @leave bus

          @emit configured: @data


        @on shout: ->
          @broadcast_to 'internal', shouted: {@id,@data}

List servers that respond
-------------------------

        @on ping: ->
          @broadcast_to 'traces', 'ping', @data
          @broadcast_to 'locations', 'ping', @data

Support-class messages
----------------------

        for event in Cuddly.events
          @on event, ->
            @broadcast_to 'support', event, @data

Public customer notification
----------------------------

        @on notify_users: ->
          @broadcast_to 'internal', 'notify', @data
          @broadcast_to 'everyone', 'notify', @data

Messages from `docker.tough-rate/notify` (to admins)
----------------------------------------------------

        @on call: ->
          @broadcast_to 'calls', 'call', @data
        @on 'statistics:add': ->
          @broadcast_to 'calls', 'statistics:add', @data

Messages to `nifty-ground` clients
----------------------------------

        @on trace: ->
          @broadcast_to 'traces', 'trace', @data

Messages from `nifty-ground` (to admins)
----------------------------------------

        @on pong: ->
          @broadcast_to 'internal', 'pong', @data
        @on trace_started: ->
          @broadcast_to 'internal', 'trace_started', @data
        @on trace_completed: ->
          @broadcast_to 'internal', 'trace_completed', @data
        @on trace_error: ->
          @broadcast_to 'internal', 'trace_error', @data

Messages from ccnq4-opensips (to admins).
-----------------------------------------

Set the `notify` configuration parameter of ccnq4-opensips to `https://server.example.net/_notify` for full effect.

        jsonBody = (require 'body-parser').json {}
        internal = @io.sockets.in 'internal'

        @post '/_notify/:msg', jsonBody, ->
          internal.emit @params.msg, @body
          @json ok:true

Messages towards `ccnq4-opensips`
---------------------------------

        @on location: ->
          @broadcast_to 'locations', 'location', @data
        @on locations: ->
          @broadcast_to 'locations', 'locations', @data
        @on registrants: ->
          @broadcast_to 'locations', 'registrants', @data

Messages from ccnq4-opensips (to admins)
----------------------------------------

        @on 'location:update': ->
          @broadcast_to 'internal', 'location:update', @data
        @on 'location:response': ->
          @broadcast_to 'internal', 'location:response', @data
        @on 'locations:response': ->
          @broadcast_to 'internal', 'locations:response', @data
        @on 'registrants:response': ->
          @broadcast_to 'internal', 'registrants:response', @data

CouchDB reverse proxy with embedded authentication.

        @include './public_proxy'

Other local services.

        @include './local/public'

    module.exports = run
    if require.main is module
      cfg = require process.env.CONFIG ? './local/config.json'
      run cfg
