    request = (require 'superagent-as-promised') require 'superagent'
    zappa  = require 'zappajs'
    Promise = require 'bluebird'
    chai = require 'chai'
    chai.should()

    describe 'Failover', ->
      port = 8088
      missing_port = port++
      failing_port = port++
      backend_port = port++
      frontend_port = port++
      silly_port = port++
      crazy_port = port++

      backend = frontend = silly = null

      before ->

        backend = zappa backend_port, ->
          @get '/', ->
            @json ok:true

          @get '/foo%2Fbar', ->
            @json foo:true

          @get '/bar/foo', ->
            @json bar:true

          @get '/hang', ->
            @json hung:true

          @get '/start-and-hang', ->
            @json starthung:true

          @get '/start-and-hang-long', ->
            @json starthung:true

          @get '/too-slow', ->
            @json hung:true

          @get '/headers-but-slow', ->
            @json hung:true

        failing_backend = zappa failing_port, ->

Just hang.

          @get '/hang', ->

Start and hang.

          @get '/start-and-hang', ->
            @res.write '{"results":[\n'
            Promise.delay 3000
            .then =>
              @res.end ']}'

Start and hang (long pause).

          @get '/start-and-hang-long', ->
            @res.write '{"results":[\n'
            Promise.delay 35000
            .then =>
              @res.end ']}'

Provide the answer before timeout.

          @get '/slow', ->
            Promise.delay 1023
            .then =>
              @json slow:true

          @get '/too-slow', ->
            Promise.delay 8000
            .then =>
              @json slow:true

          @get '/headers-but-slow', ->
            @res.writeHead 200, 'Content-Type':'application/json'
            Promise.delay 500
            .then =>
              @res.write '{'
            .then =>
              Promise.delay 1700
            .then =>
              @res.write '"to'
            .then =>
              Promise.delay 1700
            .then =>
              @res.write 'o":'
            .then =>
              Promise.delay 1700
            .then =>
              @res.write 'tru'
            .then =>
              Promise.delay 1700
            .then =>
              @res.write 'e}'
            .then =>
              Promise.delay 1700
            .then =>
              @res.end()

        make_proxy = require '../make_proxy'

        frontend = zappa frontend_port, ->

          proxy = make_proxy "http://127.0.0.1:#{missing_port}", "http://127.0.0.1:#{backend_port}"
          @get /./, ->
            proxy.call this, @request.headers

        silly = zappa silly_port, ->

          proxy = make_proxy ["http://127.0.1.0:#{failing_port}", "http://127.0.0.1:#{backend_port}"]
          @get /./, ->
            proxy.call this, @request.headers

        crazy = zappa crazy_port, ->

          proxy = make_proxy ["http://127.0.1.0:#{failing_port}"]
          @get /./, ->
            proxy.call this, @request.headers

      it 'should failover on service rejection', ->
        request
        .get "http://127.0.0.1:#{frontend_port}"
        .accept 'json'
        .then ({body}) ->
          body.should.have.property 'ok', true

      it 'should wait before service timeout', ->
        @timeout 3000
        start = Date.now()
        request
        .get "http://127.0.0.1:#{silly_port}/slow"
        .accept 'json'
        .then ({body}) ->
          body.should.have.property 'slow', true
          end = Date.now()
          duration = end-start
          chai.expect(duration).to.be.at.least 1000
          chai.expect(duration).to.be.at.most 1500

      it 'should wait on slow response', ->
        @timeout 3000
        start = Date.now()
        request
        .get "http://127.0.0.1:#{silly_port}/too-slow"
        .accept 'json'
        .then ({body}) ->
          body.should.have.property 'hung', true
          end = Date.now()
          duration = end-start
          chai.expect(duration).to.be.at.least 1500
          chai.expect(duration).to.be.at.most 2500

      it 'should failover on hung body', ->
        @timeout 10000
        start = Date.now()
        request
        .get "http://127.0.0.1:#{silly_port}/headers-but-slow"
        .accept 'json'
        .then ({body}) ->
          body.should.have.property 'too', true
          end = Date.now()
          duration = end-start
          chai.expect(duration).to.be.at.least 8700
          chai.expect(duration).to.be.at.most 9700

      it 'should failover on service timeout', ->
        @timeout 3000
        start = Date.now()
        request
        .get "http://127.0.0.1:#{silly_port}/hang"
        .accept 'json'
        .then ({body}) ->
          body.should.have.property 'hung', true
          end = Date.now()
          duration = end-start
          chai.expect(duration).to.be.at.least 1500
          chai.expect(duration).to.be.at.most 2500

      it 'should not failover on hung partial response', ->
        @timeout 6000
        start = Date.now()
        request
        .get "http://127.0.0.1:#{silly_port}/start-and-hang"
        .accept 'json'
        .then ({text}) ->

Previously we used to concatenate the results, leading to errors.

          text.should.not.eql '{"results":[\n{"starthung":true}'
          text.should.eql '{"results":[\n]}'

      it 'should not failover on hung partial response (long test)', ->
        @timeout 60000
        start = Date.now()
        request
        .get "http://127.0.0.1:#{silly_port}/start-and-hang-long"
        .accept 'json'
        .then ({text}) ->

Previously we used to concatenate the results, leading to errors.

          text.should.not.eql '{"results":[\n{"starthung":true}'
          text.should.eql '{"results":[\n]}'

      it 'should wait on slow body which is last', ->
        @timeout 10000
        start = Date.now()
        request
        .get "http://127.0.0.1:#{crazy_port}/too-slow"
        .accept 'json'
        .then ({body}) ->
          body.should.have.property 'slow', true
          end = Date.now()
          duration = end-start
          chai.expect(duration).to.be.at.least 7500
          chai.expect(duration).to.be.at.most 8500

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
