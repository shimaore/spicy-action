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

Messages towards the queuer in `huge-play`
------------------------------------------

      identity = (x) -> x

      register_message = (bus,msg,validate,mapper = identity) =>
        @on msg, ->
          return unless validate @session, @data
          @broadcast_to bus, msg, mapper @data

        @post "/_notify/#{msg}", @auth, jsonBody, ->
          unless validate @session, @body
            @res.status 400
            @res.end()
            return
          @io.to(bus).emit msg, mapper @body
          @json ok:true

      validate_place_call = (session,data) ->
        return false unless data.endpoint? and data.destination?
        return false unless typeof data.endpoint is 'string'
        return false unless typeof data.destination is 'string'
        return false unless session.admin or (session?.couchdb_roles? and data.endpoint in session.couchdb_roles)
        true

      register_message 'dial_calls', 'place-call', validate_place_call

Parameters:
- `name` (the conference name)
- `endpoint` (the calling endpoint)
- `destination` (the called number)

      validate_call_to_conference = (session,data) ->
        return false unless data.name? and data.endpoint? and data.destination?
        return false unless typeof data.name is 'string'
        return false unless typeof data.endpoint is 'string'
        return false unless typeof data.destination is 'string'
        return false unless session.admin or (session?.couchdb_roles? and data.endpoint in session.couchdb_roles)
        true

      register_message 'dial_calls', 'call-to-conference', validate_call_to_conference

Parameters:
- `agent` (the requiring, calling, agent) (the actual call might end up routed to a different agent)
- `destination` (the called number)
- `tags` (agent selection tags)

      validate_create_queuer_call = (session,data) ->
        return false unless data.agent? and data.destination?
        return false unless typeof data.agent is 'string'
        return false unless typeof data.destination is 'string'
        return false unless session.admin or (session?.couchdb_roles? and "number:#{data.agent}" in session.couchdb_roles)
        true

      register_message 'dial_calls', 'create-queuer-call', validate_create_queuer_call

Queuer messages


      validate_agent = (session,number) ->
        return false unless typeof number is 'string'
        return false unless session.admin or (session.couchdb_roles? and "number:#{number}" in session.couchdb_roles)
        true

      register_message 'dial_calls', 'queuer:log-agent-out', validate_agent

      register_message 'dial_calls', 'queuer:log-agent-in', validate_agent

      register_message 'dial_calls', 'queuer:get-agent-state', validate_agent

      validate_number_domain = (session,number_domain) ->
        return false unless typeof number_domain is 'string'
        return false unless session.admin or (session.couchdb_roles? and "number_domain:#{number_domain}" in session.couchdb_roles)
        true

      register_message 'dial_calls', 'queuer:get-egress-pool', validate_number_domain
      register_message 'dial_calls', 'queuer:get-ingress-pool', validate_number_domain

      validate_participants = (session,data) ->
        return unless data.number_domain? and data.short_name?
        {number_domain,short_name} = data
        return unless typeof number_domain is 'string'
        return unless typeof short_name is 'string'
        return unless session.admin or (session.couchdb_roles? and "number_domain:#{number_domain}" in session.couchdb_roles)

      map_participants = (data) ->
        {number_domain,short_name} = data
        full_name = "#{number_domain}-#{short_name}"

      register_message 'dial_calls', 'conference:get-participants', validate_participants, map_participants

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
      return

Unsubscribe
-----------

    unsubscribe = ->

      unless @session?.couchdb_token?
        @emit failed: {msg:'You must authenticate first.'}
        return

      room = @data

      return unless typeof room is 'string'
      @leave room
      return

    @name = "spicy-action:external-message-broker"
    pkg = require './package.json'
    {public_buses,notification_rooms,host_buses,private_buses} = require './buses'
    jsonBody = (require 'body-parser').json {}
