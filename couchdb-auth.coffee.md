Authenticate against CouchDB
----------------------------

    request = require 'superagent-as-promised'

    basic_auth = require 'basic-auth'

    @middleware = ->

Skip if the session is already established.

      if @session.couchdb_token?
        @next()
        return

Skip if the user is not trying to authenticate using Basic.

      user = basic_auth @req

      if not user?
        @next()
        return

Try our method.

      request
      .get "#{@cfg.auth_base ? @cfg.proxy_base}/_session"
      .accept 'json'
      .auth user.name, user.pass
      .then ({body}) =>
        @session.couchdb_username = body.userCtx.name
        @session.couchdb_roles = body.userCtx.roles
        @session.couchdb_token = hex_hmac_sha1 @cfg.couchdb_secret, @session.couchdb_username

Do not mask errors in the remaining middlewares.

      .then =>
        @next()
      .catch (error) ->
        throw error

    crypto = require 'crypto'
    hex_hmac_sha1 = (key,value) ->
      hmac = crypto.createHmac 'sha1', key
      hmac.update value
      hmac.digest 'hex'
