Socket.io message-broker for the private (internal) API
=======================================================

    Cuddly = require 'cuddly'

    @include = ->

Connection
==========

      @on connection: ->
        @emit welcome: {@id,name:pkg.name,version:pkg.version,public:false}

Subscribe
=========

Legacy configuration message.

      @on configure: ->

        for bus in [private_buses...,host_buses...]
          do (bus) =>
            switch @data[bus]
              when true
                @join bus
              when false
                @leave bus

        @emit configured: @data

Subscribe request

      @on join: subscribe
      @on subscribe: subscribe

Unsubscribe request

      @on leave: unsubscribe
      @on unsubscribe: unsubscribe

Rooms/busses
------------

      make_to = (room) =>
        emit: (args...) =>
          @io.to(room).emit args...

      to = {}
      for r in [private_buses...,public_buses...,host_buses...]
        do (r) =>
          to[r] = make_to r

List servers that respond
-------------------------

FIXME: `ping` and `pong` are [listed as reserved](https://socket.io/docs/emit-cheatsheet/).

      @on ping: ->
        for room in host_buses
          to[room].emit 'ping', @data

Shout: internal (admin) users notification
------------------------------------------

      @on shout: ->
        to.internal.emit 'shouted', {@id,@data}

Public customer notification
----------------------------

      @on notify_users: ->
        to.internal.emit 'notify', @data
        to.everyone.emit 'notify', @data

Internally mappable services
----------------------------

`handler` maps an event to a target bus on which it is broadcast.
More importantly, `handler` serves as a reference of all known events, thereby allowing to dispatch events to individual (non-admin) users based on their subscription requests for individual endpoints, numbers, etc.

      handler = {}

Support-class messages
----------------------

The events from the `cuddly` module:
```
report_dev
report_ops
report_csr
```
or similar events reported by other entities (for example `ccnq4-opensips/src/config/fragments/`).

      for event in Cuddly.events
        do (event) ->
          handler[event] = to.support

Messages from `huge-play`
-------------------------

      handler.call = to.calls
      handler.reference = to.calls

Messages from `thinkable-ducks`, `huge-play`, …
-----------------------------------------------

      handler['statistics:add'] = to.calls

Messages towards `nifty-ground`
-------------------------------

      handler.trace = to.traces

Messages from `nifty-ground`
----------------------------

      handler.pong = to.internal
      handler.trace_started = to.internal
      handler.trace_completed = to.internal
      handler.trace_error = to.internal

Messages towards `ccnq4-opensips`
---------------------------------

      handler.location = to.locations
      handler.locations = to.locations
      handler.registrants = to.locations
      handler.presentities = to.locations
      handler.active_watchers = to.locations

Messages from ccnq4-opensips
----------------------------

See `ccnq4-opensips/src/client/main.coffee`

      handler['location:update'] = to.internal
      handler['location:response'] = to.internal
      handler['locations:response'] = to.internal
      handler['presentities:response'] = to.internal
      handler['active_watchers:response'] = to.internal

See `ccnq4-opensips/src/registrant/main.coffee`

      handler['registrants:response'] = to.internal

Invalid source IP for registration (if endpoint has `check_ip` enabled but the value of `user_ip` does not match).
See `ccnq4-opensips/src/config/fragments/register-colocated.cfg`

      handler.script_register = to.support

Indication of rate limiting (if `rate_limit_requests` is enabled for OpenSIPS).
See `ccnq4-opensips/src/config/fragments/toolbox.cfg`

      handler.pipe_blocked = to.support

Register events
---------------

All the above events are registered below.
All events are sent in the target room/bus specified above.
All events are also sent in the rooms/busses optionally specified using the `_in` field of the event. This allows individual (non-admin) socket.io client (especially on the public API) to subscribe for these rooms/busses, and internal servers to propagate notifications directly to those users by providing values in the `_in` field in events.

      register = (event) =>
        @on event, ->
          handler[event]?.emit event, @data

Individual messages dispatch.

          if @data?._in?
            @data._in = [@data._in] if typeof @data._in is 'string'
            for room in @data._in when room.match notification_rooms
              do (room) =>
                @io.to(room).emit event, @data

        debug 'Registered event', event

      for event of handler
        do (event) => register event

Dynamically register events
---------------------------

This allows internal servers to dynamically register events (and should eventually replace the list above) by providing
- the event name
- an optional default-room name

      @on 'register', ->
        {event,default_room} = @data
        already_registered = event of handler
        debug 'Registering', {event, default_room, already_registered}

        return unless typeof event is 'string'

        to_room = to[default_room]
        if to_room?
          handler[event] = to_room
        else
          handler[event] = null
        return if already_registered
        register event

Push notifications from ccnq4-opensips
--------------------------------------

OpenSIPS doesn't support Socket.io but we're proxying its push notifications.

Set the `notify` configuration parameter of ccnq4-opensips to `https://server.example.net/_notify` for full effect.

      jsonBody = (require 'body-parser').json {}

      @post '/_notify/:msg', jsonBody, ->
        msg = @params.msg
        unless handler[msg]?
          debug "No handler for #{msg}", @body
          @json ok:false, ignore:true
          return

        handler[msg].emit msg, @body

Forward messages for specific endpoints to customers.
(This prevents having to figure out how to code the `_in` array in OpenSIPS notifications.)
See ccnq4-opensips/src/config/fragments/generic.cfg and src/config/fragments/register-colocated.cfg

        if @body?.endpoint?
          room = "endpoint:#{@body.endpoint}"
          @io.to(room).emit msg, @body

        @json ok:true

Toolbox
=======

    subscribe = ->
      room = @data
      return unless typeof room is 'string'
      @join room

    unsubscribe = ->
      root = @data
      return unless typeof room is 'string'
      @leave room

    @name = "spicy-action:internal-message-broker"
    debug = (require 'debug') @name
    pkg = require './package.json'
    {public_buses,notification_rooms,host_buses,private_buses} = require './buses'
