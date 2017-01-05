Socket.io message-broker for the public (external) API
======================================================

    @include = ->

Connection
==========

      @on connection: ->
        @join 'public' # No authentication required
        @emit joined: 'public'
        @emit welcome: {@id,name:pkg.name,version:pkg.version,public:true}

Subscribe
=========

Request to join a given notification room.

      @on join: subscribe
      @on subscribe: subscribe

Leave request

      @on leave: unsubscribe
      @on unsubscribe: unsubscribe

Publish
=======

List servers that respond
-------------------------

      @on ping: ->
        if @session.admin
          for room in host_buses
            @broadcast_to room, 'ping', @data

Messages towards `nifty-ground`
-------------------------------

      @on trace: ->
        if @session.admin
          @broadcast_to 'traces', 'trace', @data

Messages towards `ccnq4-opensips`
---------------------------------

      @on location: ->
        if @session.admin
          @broadcast_to 'locations', 'location', @data

Messages towards `exultant-songs`
---------------------------------

      @on 'place-call': ->
        if @session.admin
          @broadcast_to 'dial_calls', 'place-call', @data

Tools
=====

Subscribe
---------

    subscribe = ->

      unless @session?.couchdb_token?
        @emit failed: {msg:'You must authenticate first.'}
        return

      room = @data

      unless room? and typeof room is 'string'
        @join 'everyone'
        @emit joined: 'everyone'
        @emit ready: @user_data()
        return

      ok = false

      ok = true if room in public_buses

The notification room names have the format `<type>:<key>`.
For example 'domain:example.com', or 'number:15005551234'.
Authorization is based on the roles. The room name must match a role for the user, or the user must be an admin.

      if room.match notification_rooms
        ok = true if @session.admin or room in @session.couchdb_roles

This allows admins to receive responses from internal hosts.

      ok = true if room in private_buses and @session.admin

This allows admins to listen-in on requests sent to the internal hosts.

      ok = true if room in host_buses and @session.admin

For status, client might use the ack response, or wait for the `joined` event.

      if ok
        @join room
        @emit joined: room

      @ack? ok

Unsubscribe
-----------

    unsubscribe = ->

      unless @session?.couchdb_token?
        @emit failed: {msg:'You must authenticate first.'}
        return

      room = @data

      return unless typeof room is 'string'
      @leave room

    @name = "spicy-action:external-message-broker"
    debug = (require 'debug') @name
    {public_buses,notification_rooms,host_buses,private_buses} = require './buses'
