Authenticate and authorize using a CouchDB backend
--------------------------------------------------

    request = (require 'superagent-as-promised') require 'superagent'

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

      admin_role = @cfg.admin_role ? '_admin'

      request
      .get "#{ @cfg.auth_base }/_session"
      .accept 'json'
      .auth user.name, user.pass
      .then ({body}) =>
        @session.couchdb_username = body.userCtx.name
        @session.couchdb_roles = body.userCtx.roles
        @session.admin = admin_role in @session.couchdb_roles

Do not mask errors in the remaining middlewares.

      .then =>
        @next()
      .catch (error) ->
        throw error
