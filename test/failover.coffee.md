    request = (require 'superagent-as-promised') require 'superagent'
    zappa  = require 'zappajs'
    chai = require 'chai'
    chai.should()

    describe 'Failover', ->
      port = 8088
      missing_port = port++
      backend_port = port++
      frontend_port = port++

      backend = frontend = null

      before ->

        backend = zappa backend_port, ->
          @get '/', ->
            @json ok:true

        frontend = zappa frontend_port, ->

          make_proxy = require '../make_proxy'
          proxy = make_proxy "http://127.0.0.1:#{missing_port}", "http://127.0.0.1:#{backend_port}"
          @get '/', ->
            proxy.call this, @request.headers

      it 'should failover on service rejection', ->
        request
        .get "http://127.0.0.1:#{frontend_port}"
        .accept 'json'
        .then ({body}) ->
          body.should.have.property 'ok', true
