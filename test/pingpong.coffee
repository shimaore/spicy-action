io1 = (require 'socket.io-client') 'http://10.42.42.107:8080/'
# 'INTERFACES=lo SOCKET=https://10.42.42.108:8080/ ./supervisord.conf.sh'

io1.emit 'configure', traces:yes, calls:yes

io1.on 'trace_started', -> console.log 'trace_started'
io1.on 'trace_completed', -> console.log 'trace_completed'
io1.on 'trace_error', -> console.log 'trace_error'
io1.on 'call', -> console.log 'call'
io1.on 'report', -> console.log 'call'
io1.on 'statistics:add', -> console.log 'call'
io1.emit 'trace', reference:347, ip:'127.0.0.1'
