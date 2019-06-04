    @include = ->

      make_couchdb_proxy = require './make_couchdb_proxy'

* cfg.proxy_base (URL or array of URLs, without authentication) Servers and ports used to build proxies for various services.

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

      base = @cfg.proxy_base
      if base?
        couchdb_proxy = make_couchdb_proxy base
        @get  couchdb_urls, @auth, couchdb_proxy
        @post couchdb_urls, @auth, couchdb_proxy
        @put  couchdb_urls, @auth, couchdb_proxy
        @delete couchdb_urls, @auth, couchdb_proxy

Provisioning and ruleset(s) databases.

* cfg.provisioning_base (URL or array of URLs, without_authentication) Servers and ports used to build proxies for provisioning and rulesets. Default: cfg.proxy_base

      couchdb_urls = ///
        ^ /(
              provisioning
            | plans
            | ruleset_[\w-]+
            | rates-[\w-]+
            | cdr-[\w_-]+
            | trace-[\w-]+
            | reference-[\w-]+
          )/
        ///
      base = @cfg.provisioning_base ? @cfg.proxy_base
      if base?
        couchdb_proxy = make_couchdb_proxy base
        @get  '/provisioning', @auth, couchdb_proxy
        @get  '/plans', @auth, couchdb_proxy
        @get  '/ruleset_[\w-]+', @auth, couchdb_proxy
        @get  '/rates-[\w-]+', @auth, couchdb_proxy
        @get  '/cdr-[\w-]+', @auth, couchdb_proxy
        @get  '/trace-[\w-]+', @auth, couchdb_proxy
        @get  '/reference-[\w-]+', @auth, couchdb_proxy

        @get  couchdb_urls, @auth, couchdb_proxy
        @post couchdb_urls, @auth, couchdb_proxy
        @put  couchdb_urls, @auth, couchdb_proxy
        @delete couchdb_urls, @auth, couchdb_proxy

Tools.

* cfg.tools_base (URL or array of URLs, without_authentication) Servers and ports used to build proxies for tools. Default: cfg.proxy_base

      base = @cfg.tools_base ? @cfg.proxy_base
      if base?
        couchdb_proxy = make_couchdb_proxy base
        @get /// ^ /tools/ ///, @auth, couchdb_proxy

Logging, used for traces.

* cfg.logging_base (URL or array of URLs, without_authentication) Servers and ports used to build proxies for logging. Default: cfg.proxy_base

      base = @cfg.logging_base ? @cfg.proxy_base
      if base?
        couchdb_proxy = make_couchdb_proxy base
        @get /// ^ /logging/ ///, @auth, couchdb_proxy

FreeSwitch-generated, carrier-side CDRs.

* cfg.cdrs_base (URL or array of URLs, without_authentication) Servers and ports used to build proxies for cdrs and cdrs-client. Default: cfg.proxy_base

      base = @cfg.cdrs_base ? @cfg.proxy_base
      if base?
        couchdb_proxy = make_couchdb_proxy base
        @get  '/cdrs', @auth, couchdb_proxy
        @post '/cdrs/_all_docs', @auth, couchdb_proxy
        @post /// ^ /cdrs/_design/\w+/_view ///, @auth, couchdb_proxy
        @get  /// ^ /cdrs/ ///, @auth, couchdb_proxy

FreeSwitch-generated, client-side CDRs.

      base = @cfg.cdrs_base ? @cfg.proxy_base
      if base?
        couchdb_proxy = make_couchdb_proxy base
        @get  '/cdrs-client', @auth, couchdb_proxy
        @post '/cdrs-client/_all_docs', @auth, couchdb_proxy
        @post /// ^ /cdrs-client/_design/\w+/_view ///, @auth, couchdb_proxy
        @get  /// ^ /cdrs-client/ ///, @auth, couchdb_proxy

      return
