Validate the session
--------------------

The session is validated by ensuring that both the username and the roles array are populated.

    @middleware = create_token = ->

      if @session.couchdb_token?
        @next()
        return

      unless @session.couchdb_username? and @session.couchdb_roles?
        @session.couchdb_username = null
        @session.couchdb_roles = null
        @next()
        return

      @session.couchdb_token = hex_hmac_sha1 @cfg.couchdb_secret, @session.couchdb_username
      @next()

    crypto = require 'crypto'
    hex_hmac_sha1 = (key,value) ->
      hmac = crypto.createHmac 'sha1', key
      hmac.update value
      hmac.digest 'hex'
