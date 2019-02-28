Authenticate and authorize using a CouchDB backend
--------------------------------------------------

    seem = require 'seem'
    request = require 'superagent'

    basic_auth = require 'basic-auth'

    @middleware = seem ->

Skip if the session is already established.

      if @session.couchdb_token?
        return

Skip if the user is not trying to authenticate using Basic.

      user = basic_auth @req

      if not user?
        return

      if not @cfg.auth_base?
        return

Try our method.

* cfg.admin_role (string) Role used to indicate a CouchDB account should be considered admin (see session.admin ). Default: `_admin`

      admin_role = @cfg.admin_role ? '_admin'

* cfg.auth_base (URL without authentication) CouchDB base used to authenticate users (when basic auth is used).

      yield request
      .get "#{ @cfg.auth_base }/_session"
      .accept 'json'
      .auth user.name, user.pass
      .then ({body}) =>
        @session.couchdb_username = body.userCtx.name
        @session.couchdb_roles = body.userCtx.roles
        @session.admin = admin_role in @session.couchdb_roles

Do not mask errors in the remaining middlewares.

      return
