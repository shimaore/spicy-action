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
