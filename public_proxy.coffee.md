    @include = ->

      request = (require 'superagent-as-promised') require 'superagent'

      @get '/_spicy_action', @auth, ->
        @json
          ok:true
          username: @session.couchdb_username
          full_name: @session.full_name
          roles: @session.couchdb_roles

      make_couchdb_proxy = require './make_couchdb_proxy'

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

Legacy tools.

      couchdb_urls = ///
        ^ /_ccnq3/
        ///
      couchdb_proxy = make_couchdb_proxy @cfg.ccnq3_base ? @cfg.proxy_base
      @get  couchdb_urls, @auth, couchdb_proxy
      @post couchdb_urls, @auth, couchdb_proxy
      @put  couchdb_urls, @auth, couchdb_proxy
      @delete couchdb_urls, @auth, couchdb_proxy

New tools.

      couchdb_urls = ///
        ^ /tools/
        ///
      couchdb_proxy = make_couchdb_proxy @cfg.tools_base ? @cfg.proxy_base
      @get  couchdb_urls, @auth, couchdb_proxy

      couchdb_urls = ///
        ^ /logging/
        ///
      couchdb_proxy = make_couchdb_proxy @cfg.logging_base ? @cfg.proxy_base
      @get  couchdb_urls, @auth, couchdb_proxy

      couchdb_urls = ///
        ^ /cdrs/
        ///
      couchdb_proxy = make_couchdb_proxy @cfg.cdrs_base ? @cfg.proxy_base
      @get  '/cdrs', @auth, couchdb_proxy
      @post '/cdrs/_all_docs', @auth, couchdb_proxy
      @post /// ^ /cdrs/_design/\w+/_view ///, @auth, couchdb_proxy
      @get  couchdb_urls, @auth, couchdb_proxy
