    @include = ->

      request = require 'superagent-as-promised'

      local_auth = require './local/auth'
      @include local_auth  if local_auth.include?
      client_auth = @wrap local_auth.middleware  if local_auth.middleware?

      @get '/_spicy_action', client_auth, ->
        @json
          ok:true
          username: @session.couchdb_username
          full_name: @session.full_name
          roles: @session.couchdb_roles

      make_proxy = (base) ->
        ->
          headers = {}
          headers[k] = v for own k,v of @request.headers
          headers['X-Auth-CouchDB-Roles'] = @session.couchdb_roles.join ','
          headers['X-Auth-CouchDB-Token'] = @session.couchdb_token
          headers['X-Auth-CouchDB-UserName'] = @session.couchdb_username
          proxy = request @request.method, "#{base}#{@request.url}"
            .set headers
            .agent false
            .redirects 0
            .timeout 1000
          @request.pipe proxy
          proxy.pipe @response
          return

      couchdb_urls = ///
        ^ / u
        [a-f\d]{8} -
        [a-f\d]{4} -
        [a-f\d]{4} -
        [a-f\d]{4} -
        [a-f\d]{12}
        ($|/)
        ///

      couchdb_proxy = make_proxy @cfg.proxy_base
      @get  couchdb_urls, client_auth, couchdb_proxy
      @post couchdb_urls, client_auth, couchdb_proxy
      @put  couchdb_urls, client_auth, couchdb_proxy
      @delete couchdb_urls, client_auth, couchdb_proxy

      couchdb_urls = ///
        ^ /provisioning/
        ///
      couchdb_proxy = make_proxy @cfg.provisioning_base ? @cfg.proxy_base
      @get  '/provisioning', client_auth, couchdb_proxy
      @get  couchdb_urls, client_auth, couchdb_proxy
      @post couchdb_urls, client_auth, couchdb_proxy
      @put  couchdb_urls, client_auth, couchdb_proxy
      @delete couchdb_urls, client_auth, couchdb_proxy

      couchdb_urls = ///
        ^ /cdrs/
        ///
      couchdb_proxy = make_proxy @cfg.cdrs_base ? @cfg.proxy_base
      @get  '/cdrs', client_auth, couchdb_proxy
      @get  couchdb_urls, client_auth, couchdb_proxy
