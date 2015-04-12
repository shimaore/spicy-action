      module.exports = make_couchdb_proxy = (base,base2) ->
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

In case of error (assuming network error, hence the request was not piped yet), attempt to pipe to the failover server (if any).

          proxy.catch (error) ->
            console.log "Proxy: #{error}"
            return unless base2?
            proxy2 = request @request.method, "#{base2}#{@request.url}"
              .set headers
              .agent false
              .redirects 0
              .timeout 1000
            @request.pipe proxy2
            proxy2.pipe @response

Initial request attempt to the first backed: pipe the request to the server, pipe the response back to the client.

          @request.pipe proxy
          proxy.pipe @response
          return

