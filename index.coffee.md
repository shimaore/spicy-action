Authentication Proxy
====================

This is an authentication proxy for CouchDB, using a custom (cookie-session-based) authentication scheme.

This is also a Socket.IO server for external users, allowing the propagation of events to users, and for internal (services) users, allowing the generation of events. In other words this is an event broker.

    run = (cfg) ->
      pkg = require './package.json'
      Cuddly = require 'cuddly'
      fs = require 'fs'

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

      cfg.ssl ?= {}
      cfg.ssl.key  ?= fs.readFileSync cfg.ssl.key_file, 'utf-8'  if cfg.ssl.key_file?
      cfg.ssl.cert ?= fs.readFileSync cfg.ssl.cert_file, 'utf-8' if cfg.ssl.cert_file?

      notification_rooms = /^\w+:/

      zappa cfg.public_host, cfg.public_port, https:cfg.ssl, ->

        @use morgan:'combined'

        @helper {cfg,pkg}
        @cfg = cfg

        @helper user_data: ->
          ok: true
          username: @session?.couchdb_username
          full_name: @session?.full_name
          roles: @session?.couchdb_roles
          admin: @session?.admin

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
          @emit ready: @user_data()

Request to join a given notification room.

        @on follow: ->

          room = @data

          return unless typeof room is 'string'

The notification room names have the format `<type>:<key>`.
For example 'domain:example.com', or 'number:15005551234'.

          return unless room.match notification_rooms

Authorization for now is based on the roles. The room name must match a role for the user.

          if room in @session.couchdb_roles
            @join room

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

Rooms/busses
------------

The `traces` bus is subscribed by the `nifty-ground` servers.
The `locations` bus is subscribed by the `ccnq4-opensips` servers.
These are normally directed at admins, but might be used by notifications tools (e.g. notification-to-email tools).

        to = {}
        to[r] = @io.sockets.in r for r in [
          'calls'
          'everyone'
          'internal'
          'locations'
          'support'
          'traces'
        ]

        @on shout: ->
          to.internal.emit 'shouted', {@id,@data}

List servers that respond
-------------------------

        @on ping: ->
          to.traces.emit 'ping', @data
          to.locations.emit 'ping', @data

Public customer notification
----------------------------

        @on notify_users: ->
          to.internal.emit 'notify', @data
          to.everyone.emit 'notify', @data

Internally mappable services
----------------------------

`handler` maps an event to a target bus on which it is broadcast.

        handler = {}

Support-class messages
----------------------

        for event in Cuddly.events
          handler[event] = to.support

Messages from `docker.tough-rate/notify` (to admins)
----------------------------------------------------

        handler.call = to.calls
        handler['statistics:add'] = to.calls

Messages to `nifty-ground` clients
----------------------------------

        handler.trace = to.traces

Messages from `nifty-ground` (to admins)
----------------------------------------

        handler.pong = to.internal
        handler.trace_started = to.internal
        handler.trace_completed = to.internal
        handler.trace_error = to.internal

Messages from ccnq4-opensips (to admins).
-----------------------------------------

Set the `notify` configuration parameter of ccnq4-opensips to `https://server.example.net/_notify` for full effect.

        jsonBody = (require 'body-parser').json {}

        @post '/_notify/:msg', jsonBody, ->
          msg = @params.msg
          unless handler[msg]?
            @json ok:false, ignore:true
            return

          handler[msg].emit msg, @body
          @json ok:true

Messages towards `ccnq4-opensips`
---------------------------------

        handler.location = to.locations
        handler.locations = to.locations
        handler.registrants = to.locations

Messages from ccnq4-opensips (to admins)
----------------------------------------

        handler['location:update'] = to.internal
        handler['location:response'] = to.internal
        handler['locations:response'] = to.internal
        handler['registrants:response'] = to.internal

Register events
---------------

        for event, r of handler
          do (event,r) =>
            @on event, ->
              r.emit event, @data

Individual messages dispatch.

              if @data._in?
                @data._in = [@data._in] if typeof @data._in is 'string'
                for room in @data._in when room.match notification_rooms
                  do (room) =>
                    @io.sockets.in(room).emit event, @data

CouchDB reverse proxy with embedded authentication.

        @include './public_proxy'

Other local services.

        @include './local/public'

    module.exports = run
    if require.main is module
      cfg = require process.env.CONFIG ? './local/config.json'
      run cfg
