Authentication Proxy
====================

This is an authentication proxy for CouchDB, using a custom (cookie-session-based) authentication scheme.

This is also a Socket.IO server for external users, allowing the propagation of events to users, and for internal (services) users, allowing the generation of events. In other words this is an event broker.

    pkg = require './package.json'
    Cuddly = require 'cuddly'
    fs = require 'fs'

    zappa = require 'zappajs'
    redis = require 'socket.io-redis'

    private_buses = [
      'calls'
      'internal'
      'locations'
      'support'
      'traces'
    ]
    public_buses = [
      'everyone'
    ]

    run = (cfg) ->

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
          ok: @session?.couchdb_token?
          username: @session?.couchdb_username
          full_name: @session?.full_name
          roles: @session?.couchdb_roles
          admin: @session?.admin
          locale: @session?.locale
          timezone: @session?.timezone

        @get '/', ->
          @json
            ok:true
            name:pkg.name
            version:pkg.version
            local:(require './local/package.json').version

        @use 'cookie-parser'

Authentication, Authorization, Token
------------------------------------

Authorization is provided against different backends.

        @auth = []

        modules = [

Authenticate, authorize, and create token using local (private) methods.

          './local/auth'

Authenticate and authorize (against CouchDB backend) ...

          './couchdb-auth'

... and create token (required to prevent double-auth).

          './create-token'

Validate that a proper session was created.

          './auth-required'
        ]

        for auth_name in modules
          auth_module = require auth_name
          @include auth_module  if auth_module.include?
          @auth.push @wrap auth_module.middleware if auth_module.middleware?

Session
-------

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

Connection
----------

Local pub/sub logic.

        @on connection: ->
          @join 'public' # No authentication required
          @emit joined: 'public'
          @emit welcome: {@id,name:pkg.name,version:pkg.version,public:true}

Join request (from client)
--------------------------

Request to join a given notification room.

        @on join: ->

          unless @session?.couchdb_token?
            @emit failed: {msg:'You must authenticate first.'}
            return

          room = @data

          unless room? and typeof room is 'string'
            @join 'everyone'
            @emit joined: 'everyone'
            @emit ready: @user_data()
            return

          ok = false

          ok = true if room in public_buses
          ok = true if room in private_buses and @session.admin

The notification room names have the format `<type>:<key>`.
For example 'domain:example.com', or 'number:15005551234'.
Authorization for now is based on the roles. The room name must match a role for the user.

          if room.match notification_rooms
            ok = true if @session.admin or room in @session.couchdb_roles

For status, client might use the ack response, or wait for the `joined` event.

          if ok
            @join room
            @emit joined: room

          @ack? ok

Leave request (from client)
---------------------------

        @on leave: ->

          unless @session?.couchdb_token?
            @emit failed: {msg:'You must authenticate first.'}
            return

          room = @data

          return unless typeof room is 'string'
          @leave room

Messages towards the back-end CCNQ servers
------------------------------------------

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

Local services
--------------

Order is important here, since these services may fallback to using the `public_proxy` versions with `@next 'route'`.

        @include './local/public'

CouchDB reverse proxy with embedded authentication
--------------------------------------------------

        @include './public_proxy'


Internal (services)
====================

These need to be able to pub/sub.

      zappa cfg.internal_host, cfg.internal_port, ->

        @use morgan:'combined'

        @helper {cfg,pkg}
        @cfg = cfg

        @use 'cookie-parser'

Authentication, Authorization, Token
------------------------------------

        @auth = []

        modules = [

Authenticate, authorize, and create token.

          './couchdb-auth'
          './create-token'

Fail if not authenticated.

          './auth-required'
        ]

        for auth_name in modules
          auth_module = require auth_name
          @include auth_module  if auth_module.include?
          @auth.push @wrap auth_module.middleware if auth_module.middleware?

Session
-------

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

          for bus in private_buses
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
        make_to = (room) =>
          emit: =>
            @io.to(room).emit arguments...

        for r in private_buses
          do (r) =>
            to[r] = make_to r
        for r in public_buses
          do (r) =>
            to[r] = make_to r

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
          do (event) ->
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
            debug "No handler for #{msg}", @body
            @json ok:false, ignore:true
            return

          handler[msg].emit msg, @body

Forward messages for specific endpoints to customers.
(This prevents having to figure out how to code the `_in` array in OpenSIPS notifications.)
See ccnq4-opensips/src/config/fragments/generic.cfg and src/config/fragments/register-colocated.cfg

          if @body.endpoint?
            room = "endpoint:#{endpoint}"
            @io.to(room).emit msg, @body

          @json ok:true

Messages towards `ccnq4-opensips`
---------------------------------

        handler.location = to.locations
        handler.locations = to.locations
        handler.registrants = to.locations
        handler.presentities = to.locations
        handler.active_watchers = to.locations

Messages from ccnq4-opensips (to admins)
----------------------------------------

See ccnq4-opensips/src/client/main.coffee

        handler['location:update'] = to.internal
        handler['location:response'] = to.internal
        handler['locations:response'] = to.internal
        handler['presentities:response'] = to.internal
        handler['active_watchers:response'] = to.internal

See ccnq4-opensips/src/registrant/main.coffee

        handler['registrants:response'] = to.internal

Invalid source IP for registration (if endpoint has `user_ip`)

        handler.script_register = to.suport

Register notification (off by default)

        handler.location = to.support

Indication of rate limiting (if `rate_limit_requests` is enabled for OpenSIPS)

        handler.pipe_blocked = to.support

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
                    @io.to(room).emit event, @data

Export
======

    module.exports = run
    if require.main is module
      cfg = require process.env.CONFIG ? './local/config.json'
      run cfg
