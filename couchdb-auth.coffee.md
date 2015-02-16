Authenticate against CouchDB
----------------------------

    request = require 'superagent-as-promised'

    @include = ->
      @use 'cookie-parser'

    basic_auth = require 'basic-auth'

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
        .auth user.name, user.pass
        .then ->
          @session.couchdb_username = user.name
          @next()
        .catch ->
          need_auth()
          return
