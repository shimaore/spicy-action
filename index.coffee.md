Authentication Proxy
====================

This is an authentication proxy for CouchDB, using a custom (cookie-session-based) authentication scheme.

This is also a Socket.IO server for external users, allowing the propagation of events to users, and for internal (services) users, allowing the generation of events. In other words this is an event broker.

    @name = "spicy-action:index"
    fs = require 'fs'

    zappa = require 'core-zappa'
    app = require './app'

    run = (cfg,local) ->

External (public) service
=========================

      if cfg.ssl?.key_file?
        cfg.ssl.key  ?= fs.readFileSync cfg.ssl.key_file, 'utf-8'
      if cfg.ssl?.cert_file?
        cfg.ssl.cert ?= fs.readFileSync cfg.ssl.cert_file, 'utf-8'

      if cfg.public_port?
        options =
          host: cfg.public_host
          port: cfg.public_port
          https: cfg.ssl
          io: false

        zappa options, app cfg, local

Export
======

    module.exports = run
    if require.main is module
      cfg = require 'ccnq4-config'
      run cfg, {}
