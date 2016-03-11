    @include = ->

      request = (require 'superagent-as-promised') require 'superagent'

Service presence.

      @get '/_spicy_action', @auth, ->
        @json
          ok:true
          username: @session.couchdb_username
          full_name: @session.full_name
          roles: @session.couchdb_roles
          admin: @session.admin

      make_couchdb_proxy = require './make_couchdb_proxy'

User databases.

      couchdb_urls = ///
        ^ / u
        [a-f\d]{8} -
        [a-f\d]{4} -
        [a-f\d]{4} -
        [a-f\d]{4} -
        [a-f\d]{12}
        ($|/)
        ///

      couchdb_proxy = make_couchdb_proxy @cfg.proxy_base
      @get  couchdb_urls, @auth, couchdb_proxy
      @post couchdb_urls, @auth, couchdb_proxy
      @put  couchdb_urls, @auth, couchdb_proxy
      @delete couchdb_urls, @auth, couchdb_proxy

Provisioning and ruleset(s) databases.

      couchdb_urls = ///
        ^ /(provisioning|ruleset_[a-z\d_-]+)/
        ///
      couchdb_proxy = make_couchdb_proxy @cfg.provisioning_base ? @cfg.proxy_base
      @get  '/provisioning', @auth, couchdb_proxy
      @get  '/ruleset_[a-z\d_-]+', @auth, couchdb_proxy
      @get  couchdb_urls, @auth, couchdb_proxy
      @post couchdb_urls, @auth, couchdb_proxy
      @put  couchdb_urls, @auth, couchdb_proxy
      @delete couchdb_urls, @auth, couchdb_proxy

Tools.

      couchdb_proxy = make_couchdb_proxy @cfg.tools_base ? @cfg.proxy_base
      @get /// ^ /tools/ ///, @auth, couchdb_proxy

Logging, used for traces.

      couchdb_proxy = make_couchdb_proxy @cfg.logging_base ? @cfg.proxy_base
      @get /// ^ /logging/ ///, @auth, couchdb_proxy

Carrier-side CDRs.

      couchdb_urls = ///
        ^ /cdrs/
        ///
      couchdb_proxy = make_couchdb_proxy @cfg.cdrs_base ? @cfg.proxy_base
      @get  '/cdrs', @auth, couchdb_proxy
      @post '/cdrs/_all_docs', @auth, couchdb_proxy
      @post /// ^ /cdrs/_design/\w+/_view ///, @auth, couchdb_proxy
      @get  /// ^ /cdrs/ ///, @auth, couchdb_proxy
