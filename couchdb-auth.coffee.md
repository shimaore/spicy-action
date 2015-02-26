Authenticate against CouchDB
----------------------------

    request = require 'superagent-as-promised'

    @include = ->
      @use 'cookie-parser'

    basic_auth = require 'basic-auth'

    cfg = require './local/config.json'

    @middleware = ->
      if @session.couchdb_username?
        @next()
        return

      user = basic_auth @req

      need_auth = =>
        @res.writeHead 401, 'WWW-Authenticate': "Basic: realm=#{@pkg.name}"
        @res.end()
        return

      if not credentials?
        need_auth()
        return

      Promise.resolve()
      .then ->
        request
        .get "#{@cfg.proxy_base}/_session"
        .accept 'json'
        .auth user.name, user.pass
        .then ({body}) ->
          @session.couchdb_username = body.userCtx.name
          @session.couchdb_roles = body.userCtx.roles
          @session.couchdb_token = hex_hmac_sha1 @cfg.couchdb_secret, @session.couchdb_username
          @next()
        .catch ->
          need_auth()
          return

    crypto = require 'crypto'
    hex_hmac_sha1 = (key,value) ->
      hmac = crypto.createHmac 'sha1', key
      hmac.update value
      hmac.digest 'hex'
