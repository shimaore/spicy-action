    @include = ->

Service presence.

      @get '/_spicy_action', @auth, ->
        @json @user_data()

      @post '/_logout', ->
        @req.session.regenerate (err) =>
          if err
            @res.status 500
            @json ok: false
          else
            @json ok: true
