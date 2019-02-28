Validate the session
--------------------

The session is validated by ensuring that both the username and the roles array are populated.

    @middleware = create_token = ->

      if @req.session.couchdb_token?
        return

      unless @req.session.couchdb_username? and @req.session.couchdb_roles?
        @req.session.couchdb_username = null
        @req.session.couchdb_roles = null
        return

      unless @cfg.couchdb_secret?
        return

      @req.session.couchdb_token = hex_hmac_sha1 @cfg.couchdb_secret, @req.session.couchdb_username
      return

    crypto = require 'crypto'
    hex_hmac_sha1 = (key,value) ->
      hmac = crypto.createHmac 'sha1', key
      hmac.update value
      hmac.digest 'hex'
