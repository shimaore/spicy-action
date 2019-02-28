    @middleware = auth_required = ->
      if @session.couchdb_token?
        return
      @session = null
      @res
        .status 401
        .set 'WWW-Authenticate': "Basic: realm=#{@pkg.name}"
      @json error: 'Not authenticated'
      @res.end()
      return
