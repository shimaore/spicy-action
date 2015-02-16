    io = require 'socket.io-client'

    s = io 'http://localhost:3000'
    s.on 'connect', ->
      console.dir connect:arguments
    s.on 'reconnect', ->
      console.dir reconnect:arguments
    s.on 'error', ->
      console.dir reconnect:arguments
    s.on 'welcome', ->
      console.dir welcome:arguments
      s.emit 'shout', message:"you rule!"
    s.on 'shouted', ->
      console.dir shouted:arguments
    s.on 'disconnect', ->
      console.dir disconnect:arguments
