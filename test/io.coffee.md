Requires e.g.

```
docker run --rm -p 6379:6379 shimaore/redis-server
```

but doesn't currently work (`Ready check failed: Redis connection gone from end event. at RedisClient.on_info_cmd (node_modules/socket.io-redis/node_modules/redis/index.js:368:35))`).

    Promise = require 'bluebird'
    describe 'internal', ->
      it.skip "should not propagate `internal` messages on the private port if we did not subscribe to `internal`", (done) ->
        run = require '../index'
        run
          public_host: "127.0.0.1"
          public_port: 52080
          internal_host: "127.0.0.1"
          internal_port: 53080
          proxy_base: "https://example.net:6984"
          redis:
            host: "localhost"
            port: 6379
          session_secret: "223635e7562ac62e9b7942b11f69ef1bd778f08f"
          couchdb_secret: "5ca0739df995dfd0c6fa29ca636ba9584c4f5a35"

        @timeout 10*1000

        Promise.delay 5000
        .then ->
          io1 = (require 'socket.io-client') 'http://127.0.0.1:53080'

          io1.on 'welcome', ->
            @emit configure: support: true

          io1.on 'configured', ->
            request = require 'superagent'
            request.post 'http://127.0.0.1:53080/_notify/test'
              .type 'json'
              .accept 'json'
              .send testing:true
              .then ->
                Promise.delay 1500
              .then ->
                done()

          io1.on 'test', ->
            done 'Received message'

      it.skip "should propagate `internal` messages on the public port if admin", ->
        io2 = (require 'socket.io-client') 'http://127.0.0.1:52080'

      it.skip 'should propagate directed messages on the public port', ->
