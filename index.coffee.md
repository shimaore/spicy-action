Authentication Proxy
====================

This is an authentication proxy for CouchDB, using a custom (cookie-session-based) authentication scheme.

This is also a Socket.IO server for external users, allowing the propagation of events to users, and for internal (services) users, allowing the generation of events. In other words this is an event broker.

    pkg = require './package.json'
    @name = "spicy-action:index"
    fs = require 'fs'

    zappa = require 'zappajs'
    redis = require 'socket.io-redis'
    connect_redis = require 'connect-redis'

    run = (cfg,local) ->

Default options for `helmet`.

      local.security ?= {}

External (public) service
=========================

      if cfg.ssl?.key_file?
        cfg.ssl.key  ?= fs.readFileSync cfg.ssl.key_file, 'utf-8'
      if cfg.ssl?.cert_file?
        cfg.ssl.cert ?= fs.readFileSync cfg.ssl.cert_file, 'utf-8'

      if cfg.public_port?
        options =
          host: cfg.public_host
          port: cfg.public_port
          https: cfg.ssl
        options.server = 'cluster' if cfg.cluster

        zappa options, ->

          @use helmet: local.security

          @helper {cfg,pkg}
          @cfg = cfg

          @helper user_data: ->
            res =
              ok: @session?.couchdb_token?
              username: @session?.couchdb_username
              full_name: @session?.full_name
              roles: @session?.couchdb_roles
              admin: @session?.admin
              locale: @session?.locale
              timezone: @session?.timezone
            if @session.user_params?
              for own k,v of @session.user_params
                res[k] ?= v
            res

          @get '/', ->
            @json
              ok:true
              name:pkg.name
              version:pkg.version
              local:local.pkg.version

Authentication, Authorization, Token
------------------------------------

Authorization is provided against different backends.

          @auth = []

          modules = [

Authenticate, authorize, and create token using local (private) methods.

            local.auth

Authenticate and authorize (against CouchDB backend) ...

            './couchdb-auth'

... and create token (required to prevent double-auth).

            './create-token'

Validate that a proper session was created.

            './auth-required'
          ]

          for auth_module in modules
            if typeof auth_module is 'string'
              auth_module = require auth_module
            @include auth_module  if auth_module.include?
            @auth.push @wrap auth_module.middleware if auth_module.middleware?

Session
-------

Express: Store our session in Redis so that we can offload the Socket.IO piece to a different server if needed.

          session_redis = cfg.session_redis ? cfg.redis
          if session_redis? and cfg.session_secret?
            session_store = connect_redis @session
            @use session:
              store: new session_store session_redis
              secret: cfg.session_secret
              resave: true
              unset: 'destroy'
              saveUninitialized: true
              cookie:
                maxAge: cfg.session_maxage ? 30*60*1000
                secure: cfg.session_secure ? true

Socket.IO: allow broadcast across multiple Socket.IO servers (through Redis pub/sub).

          io_redis = cfg.io_redis ? cfg.redis
          if io_redis?
            @io.adapter redis io_redis
            @include './external-message-broker'

Local services
--------------

Order is important here, since these services may fallback to using the `public_proxy` versions with `@next 'route'`.

          @include local.public

CouchDB reverse proxy with embedded authentication
--------------------------------------------------

          @include './public_proxy'

          return


Internal (services)
====================

These need to be able to pub/sub.

      if cfg.internal_host? and cfg.internal_port?
        zappa cfg.internal_host, cfg.internal_port, ->

          @helper {cfg,pkg}
          @cfg = cfg

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

          session_redis = cfg.session_redis ? cfg.redis
          if session_redis? and cfg.session_secret
            session_store = connect_redis @session
            @use session:
              store: new session_store session_redis
              secret: cfg.session_secret
              resave: true
              unset: 'destroy'
              saveUninitialized: false

Socket.IO: allow broadcast across multiple Socket.IO servers (through Redis pub/sub).

          io_redis = cfg.io_redis ? cfg.redis
          if io_redis?
            @io.adapter redis io_redis
            @include './internal-message-broker'

          @get '/', ->
            @json
              ok:true
              name:pkg.name
              version:pkg.version
              local:local.pkg.version


Export
======

    module.exports = run
    if require.main is module
      cfg = require 'ccnq4-config'
      run cfg, {}
