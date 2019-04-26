Authentication Proxy
====================

This is an authentication proxy for CouchDB, using a custom (cookie-session-based) authentication scheme.

This is also a Socket.IO server for external users, allowing the propagation of events to users, and for internal (services) users, allowing the generation of events. In other words this is an event broker.

    pkg = require './package.json'
    @name = "spicy-action:index"
    fs = require 'fs'

    zappa = require 'core-zappa'
    connect_redis = require 'connect-redis'
    session = require 'express-session'

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
          io: false

        zappa options, ->

          @use helmet: local.security

          @helper {cfg,pkg}
          @cfg = cfg

          @helper user_data: ->
            res =
              ok: @req.session?.couchdb_token?
              username: @req.session?.couchdb_username
              full_name: @req.session?.full_name
              roles: @req.session?.couchdb_roles
              admin: @req.session?.admin
              locale: @req.session?.locale
              timezone: @req.session?.timezone
            if @req.session?.user_params?
              for own k,v of @req.session.user_params
                res[k] ?= v
            res

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
            await @include auth_module  if auth_module.include?
            @auth.push @wrap auth_module.middleware if auth_module.middleware?

Session
-------

Express: Store our session in Redis so that we can offload the Socket.IO piece to a different server if needed.

          session_redis = cfg.session_redis ? cfg.redis
          if session_redis? and cfg.session_secret?
            session_store = connect_redis session
            @use session
              store: new session_store session_redis
              secret: cfg.session_secret
              resave: true
              unset: 'destroy'
              saveUninitialized: true
              cookie:
                maxAge: cfg.session_maxage ? 30*60*1000
                secure: cfg.session_secure ? true

Local services
--------------

Order is important here, since these services may fallback to using the `public_proxy` versions with `next 'route'`.

          await @include local.public

          @get '/', ->
            @json
              ok:true
              name:pkg.name
              version:pkg.version
              local:local.pkg.version

CouchDB reverse proxy with embedded authentication
--------------------------------------------------

          await @include require './public_proxy'

          return


Export
======

    module.exports = run
    if require.main is module
      cfg = require 'ccnq4-config'
      run cfg, {}
