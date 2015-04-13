Multiple-backends interface for CouchDB
=======================================

      make_proxy = require './make_proxy'

      module.exports = make_couchdb_proxy = (bases...) ->
        proxy = make_proxy bases...
        ->
          headers = {}
          headers[k] = v for own k,v of @request.headers

Using [proxy authentication](http://docs.couchdb.org/en/latest/api/server/authn.html#api-auth-proxy) in CouchDB.

          headers['X-Auth-CouchDB-Roles'] = @session.couchdb_roles.join ','
          headers['X-Auth-CouchDB-Token'] = @session.couchdb_token
          headers['X-Auth-CouchDB-UserName'] = @session.couchdb_username

          proxy.call this, headers
