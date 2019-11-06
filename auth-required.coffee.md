    @middleware = auth_required = ->
      if @req.session?.couchdb_token?
        return
      @req.session = null
      @res
        .status 401
        .set 'WWW-Authenticate': "Basic: realm=spicy-action"
      @json error: 'Not authenticated'
      @res.end()
      return
