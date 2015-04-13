    request = (require 'superagent-as-promised') require 'superagent'
    zappa  = require 'zappajs'
    chai = require 'chai'
    chai.should()

    describe 'Failover', ->
      port = 8088
      missing_port = port++
      backend_port = port++
      frontend_port = port++
      silly_port = port++

      backend = frontend = silly = null

      before ->

        backend = zappa backend_port, ->
          @get '/', ->
            @json ok:true

          @get '/foo%2Fbar', ->
            @json foo:true

          @get '/bar/foo', ->
            @json bar:true

        make_proxy = require '../make_proxy'

        frontend = zappa frontend_port, ->

          proxy = make_proxy "http://127.0.0.1:#{missing_port}", "http://127.0.0.1:#{backend_port}"
          @get /./, ->
            proxy.call this, @request.headers

        silly = zappa silly_port, ->

          proxy = make_proxy ["http://127.0.1.0:#{backend_port}", "http://127.0.0.1:#{backend_port}"]
          @get /./, ->
            proxy.call this, @request.headers

      it 'should failover on service rejection', ->
        request
        .get "http://127.0.0.1:#{frontend_port}"
        .accept 'json'
        .then ({body}) ->
          body.should.have.property 'ok', true

      it 'should failover on service timeout', ->
        request
        .get "http://127.0.0.1:#{silly_port}"
        .accept 'json'
        .then ({body}) ->
          body.should.have.property 'ok', true

      it 'should handle paths', ->
        request
        .get "http://127.0.0.1:#{frontend_port}/bar/foo"
        .accept 'json'
        .then ({body}) ->
          body.should.have.property 'bar', true

      it 'failover should deal properly with URL encoding', ->
        request
        .get "http://127.0.0.1:#{frontend_port}/foo%2Fbar"
        .accept 'json'
        .then ({body}) ->
          body.should.have.property 'foo', true
