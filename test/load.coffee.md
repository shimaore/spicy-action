    describe 'Modules', ->
      modules = [
        'auth-required'
        'couchdb-auth'
        'create-token'
        'index'
        'make_couchdb_proxy'
        'make_plain_proxy'
        'make_proxy'
        'public_proxy'
      ]
      for m in modules
        do (m) ->
          it "#{m} should load", ->
            require "../#{m}"

    describe 'The application', ->
      app = require '../app'
      zappa = require 'core-zappa'
      cfg = {}
      local = {}
      await zappa.app -> await app.call this, cfg, local
