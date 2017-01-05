    describe 'Modules', ->
      modules = [
        'auth-required'
        'buses'
        'couchdb-auth'
        'create-token'
        'external-message-broker'
        'index'
        'internal-message-broker'
        'make_couchdb_proxy'
        'make_plain_proxy'
        'make_proxy'
        'public_proxy'
      ]
      for m in modules
        do (m) ->
          it "#{m} should load", ->
            require "../#{m}"
