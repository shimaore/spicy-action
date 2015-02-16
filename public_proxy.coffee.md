    @include = ->

      request = require 'superagent-as-promised'

      local_auth = require './local/auth'
      @include local_auth  if local_auth.include?
      client_auth = @wrap local_auth.middleware  if local_auth.middleware?

      @get '/_spicy_action', client_auth, ->
        @json
          ok:true
          full_name: @session.full_name

      couchdb_proxy = ->
          headers = {}
          headers[k] = v for own k,v of @request.headers
          headers['X-Auth-CouchDB-Roles'] = @session.couchdb_roles
          headers['X-Auth-CouchDB-Token'] = @session.couchdb_token
          headers['X-Auth-CouchDB-UserName'] = @session.couchdb_username
          proxy = request @request.method, "#{@cfg.proxy_base}#{@request.url}"
            .set headers
            .agent false
            .redirects 0
            .timeout 1000
          @request.pipe proxy
          proxy.pipe @response
          return

      couchdb_urls = /^\/(u[a-f\d]{8}-[a-f\d]{4}-[a-f\d]{4}-[a-f\d]{4}-[a-f\d]{12})($|\/)/
      @get  couchdb_urls, client_auth, couchdb_proxy
      @post couchdb_urls, client_auth, couchdb_proxy
      @put  couchdb_urls, client_auth, couchdb_proxy
      @delete couchdb_urls, client_auth, couchdb_proxy
