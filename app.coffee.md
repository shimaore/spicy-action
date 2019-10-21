    pkg = require './package.json'
    @name = 'spicy-action:app'

    connect_redis = require 'connect-redis'
    session = require 'express-session'

    module.exports = (cfg,local) ->

      @use helmet: local.security ? {}

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

Authenticate and authorize (against CouchDB backend) ...

        './couchdb-auth'

... and create token (required to prevent double-auth).

        './create-token'

Validate that a proper session was created.

        './auth-required'
      ]

Authenticate, authorize, and create token using local (private) methods.

      modules.unshift local.auth if local.auth?

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

      await @include local.public if local.public?

      @get '/', ->
        @json
          ok:true
          name:pkg.name
          version:pkg.version
          local:local.pkg.version

      return
