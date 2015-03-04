Authentication Proxy
====================

This is an authentication proxy for CouchDB, using a custom (cookie-session-based) authentication scheme.

This is also a Socket.IO server for external users, allowing the propagation of events to users, and for internal (services) users, allowing the generation of events. In other words this is an event broker.

    run = ->
      cfg = require './local/config.json'
      pkg = require './package.json'

      zappa = require 'zappajs'

      redis = require 'socket.io-redis'

      auth_required = ->
        if @session.couchdb_token?
          @next()
          return
        @session = null
        @res.writeHead 401, 'WWW-Authenticate': "Basic: realm=#{@pkg.name}"
        @json error: 'Not authenticated'
        @res.end()
        return

External (public) service.
-------------------------

      zappa cfg.public_host, cfg.public_port, https:cfg.ssl, ->

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

Socket.IO: allow broadcast across multiple Socket.IO servers (through Redis pub/sub).

        @io.adapter redis cfg.redis

Local pub/sub logic.

        @on connection: ->
          @join 'public' # No authentication required
          @emit welcome: {@id}

        @on join: ->
          unless @session?.couchdb_username?
            @emit failed: {msg:'You must authenticate first.'}
            return
          @join 'everyone'
          if @session.admin
            @join 'internal'
            @join 'calls'
          @emit ready: roles:@session.couchdb_roles

        @on trace: ->
          if @session.admin
            @broadcast_to 'traces', 'trace', @data

CouchDB reverse proxy with embedded authentication.

        @helper {cfg,pkg}
        @cfg = cfg
        @include './public_proxy'

Other local services.

        @include './local/public'

Internal (services): these need to be able to pub/sub and proxy.
--------------------

      zappa cfg.internal_host, cfg.internal_port, ->

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

        @helper {cfg,pkg}

        @get '/', ->
          @json
            ok:true
            name:pkg.name
            version:pkg.version
            local:(require './local/package.json').version

        @on connection: ->
          @emit welcome: {@id}
          @join 'internal'

        @on configure: ->
          switch @data.traces
            when true
              @join 'traces'
            when false
              @leave 'traces'
          switch @data.calls
            when true
              @join 'calls'
            when false
              @leave 'calls'

        @on shout: ->
          @broadcast_to 'internal', shouted: {@id,@data}

        @on notify_users: ->
          @broadcast_to 'internal', 'notify', @data
          @broadcast_to 'everyone', 'notify', @data

        @on call: ->
          @broadcast_to 'calls', 'call', @data

        @on trace: ->
          @broadcast_to 'traces', 'trace', @data
        @on trace_started: ->
          @broadcast_to 'internal', 'trace_started', @data
        @on trace_completed: ->
          @broadcast_to 'internal', 'trace_completed', @data
        @on trace_error: ->
          @broadcast_to 'internal', 'trace_error', @data

CouchDB reverse proxy with embedded authentication.

        @helper {cfg,pkg}
        @cfg = cfg
        @include './public_proxy'

Other local services.

        @include './local/public'

    run()
