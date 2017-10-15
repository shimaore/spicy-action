Socket.io message-broker for the private (internal) API
=======================================================

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

      to = {}
      for r in [private_buses...,public_buses...,host_buses...]
        do (r) =>
          to[r] = true

Internally mappable services
----------------------------

`handler` maps an event to a target bus on which it is broadcast.
More importantly, `handler` serves as a reference of all known events, thereby allowing to dispatch events to individual (non-admin) users based on their subscription requests for individual endpoints, numbers, etc.

      handler = {}

Support-class messages
----------------------

The events from the `cuddly` and `tangible` modules:
```
report_dev
report_ops
report_csr
```
or similar events reported by other entities (for example `ccnq4-opensips/src/config/fragments/`).

      handler.report_dev = 'support'
      handler.report_ops = 'support'
      handler.report_csr = 'support'

Messages from `huge-play`
-------------------------

      handler.call = 'calls'

Messages from `thinkable-ducks`, `huge-play`, …
-----------------------------------------------

      handler['statistics:add'] = 'calls'

Messages towards `nifty-ground`
-------------------------------

      handler.trace = 'traces'

Messages from `nifty-ground`
----------------------------

      handler.trace_started = 'internal'
      handler.trace_completed = 'internal'
      handler.trace_error = 'internal'

Messages towards `ccnq4-opensips`
---------------------------------

      handler.location = 'locations'
      handler.locations = 'locations'
      handler.registrants = 'locations'
      handler.presentities = 'locations'
      handler.active_watchers = 'locations'

Messages from ccnq4-opensips
----------------------------

See `ccnq4-opensips/src/client/main.coffee`

      handler['location:update'] = 'internal'
      handler['location:response'] = 'internal'
      handler['locations:response'] = 'internal'
      handler['presentities:response'] = 'internal'
      handler['active_watchers:response'] = 'internal'

See `ccnq4-opensips/src/registrant/main.coffee`

      handler['registrants:response'] = 'internal'

Register events
---------------

All the above events are registered below.
All events are sent in the target room/bus specified above.
All events are also sent in the rooms/busses optionally specified using the `_in` field of the event. This allows individual (non-admin) socket.io client (especially on the public API) to subscribe for these rooms/busses, and internal servers to propagate notifications directly to those users by providing values in the `_in` field in events.

      register = (event) =>
        @on event, ->

Individual messages dispatch.

          return unless @data?._in?
          @data._in = [@data._in] if typeof @data._in is 'string'

          destination = null

          @data._in
          .filter (room) -> room.match notification_rooms
          .forEach (room) =>
            destination ?= @io
            destination = destination.to room

           destination?.emit event, @data

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

        handler[event] = default_room
        return if already_registered
        register event

Push notifications
------------------

      jsonBody = (require 'body-parser').json {}

Forward registered messages.

      @post '/_notify/:msg', jsonBody, ->
        {msg} = @params

        unless msg of handler
          @res.status 404
          @res.end()
          return

        unless @body?
          @res.status 400
          @res.end()
          return

        room = handler[msg]
        @io.to(room).emit msg, @body
        @json ok:true
        return

Forward messages for specific endpoints to customers.

      @post '/_notify_endpoint/:msg', jsonBody, ->
        {msg} = @params

        unless @body?.endpoint?
          @res.status 400
          @res.end()
          return

        room = "endpoint:#{@body.endpoint}"
        @io.to(room).emit msg, @body
        @json ok:true
        return

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
    debug = (require 'tangible') @name
    pkg = require './package.json'
    {public_buses,notification_rooms,host_buses,private_buses} = require './buses'
