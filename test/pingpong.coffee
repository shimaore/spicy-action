# io1 = (require 'socket.io-client') 'http://10.42.42.107:8080/'
io1 = (require 'socket.io-client') 'http://127.0.0.1:8080/'
# 'INTERFACES=lo SOCKET=https://10.42.42.108:8080/ ./supervisord.conf.sh'

io1.emit 'configure', traces:yes, calls:yes

io1.on 'trace_started', -> console.log 'trace_started'
io1.on 'trace_completed', -> console.log 'trace_completed'
io1.on 'trace_error', -> console.log 'trace_error'
io1.on 'call', (data) -> console.log 'call', data
io1.on 'report', (data) -> console.log 'report', data
io1.on 'statistics:add', (data) -> console.log 'statistics:add', data
# io1.emit 'trace', reference:347, ip:'127.0.0.1'
io1.on 'test', (data) -> console.log 'test', data

request = (require 'superagent-as-promised') require 'superagent'
# request.post 'http://10.42.42.107:8080/_notify/test'
request.post 'http://127.0.0.1:8080/_notify/test'
  .type 'json'
  .accept 'json'
  .send testing:true
  .end()
