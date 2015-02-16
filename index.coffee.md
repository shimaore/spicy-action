Authentication Proxy
--------------------

This is an authentication proxy for CouchDB, using a custom (cookie-session-based) authentication scheme.

This is also a Socket.IO server for external users, allowing the propagation of events to users, and for internal (services) users, allowing the generation of events. In other words this is an event broker.

    run = ->
      cfg = require './local/config.json'
      pkg = require './package.json'

      zappa = require 'zappajs'

      redis = require 'socket.io-redis'

      redis_adapter = redis cfg.redis

External (public) service.

      zappa cfg.public_host, cfg.public_port, https:cfg.ssl, ->

        @use (require 'cookie-parser')()

Express: Store our session in Redis so that we can offload the Socket.IO piece to a different server if needed.

        session_store = (require 'connect-redis') @session
        @use session:
          store: new session_store cfg.redis
          secret: cfg.session_secret
          resave: true
          saveUnitialized: true

Socket.IO: allow broadcast across multiple Socket.IO servers (through Redis pub/sub).

        @io.adapter redis_adapter

Local pub/sub logic.

        @on connection: ->
          unless @session.couchdb_username
            @emit error: 'You must authenticate first.'
            return

          @emit welcome: {@id}
          @join 'everyone'

CouchDB reverse proxy with embedded authentication.

        @helper {cfg}
        @include './public_proxy'

Internal (services): these only need to be able to pub/sub.

      zappa cfg.internal_host, cfg.internal_port, ->

Socket.IO: allow broadcast across multiple Socket.IO servers (through Redis pub/sub).

        @io.adapter redis_adapter

Use CouchDB authentication.

        @helper {cfg,pkg}
        @use (require 'cookie-parser')()
        couchdb_auth = require './couchdb-auth'
        @include couchdb_auth  if couchdb_auth.include?
        @use @wrap couchdb_auth.middleware  if couchdb_auth.middleware?

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
          @broadcast_to 'internal', @data
          @broadcast_to 'everyone', @data

        @on call: ->
          @broadcast_to 'calls', 'call', @data

        @on trace: ->
          @broadcast_to 'traces', 'trace', @data

    run()
