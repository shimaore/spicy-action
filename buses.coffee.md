The `public` room
-----------------

There is a fully-public (no authentication required) bus called `public`;
anyone connecting to socket.io on the public interface is subscribed to it.

The public rooms
----------------

Public buses require some level of authentication but are otherwise not restricted.

    @public_buses = [
      'everyone'
    ]

Notification rooms
------------------

Anyone may subscribe to notifications for any endpoint, number, number-domain, etc. listed in their `roles`;
admins may subscribe to notifications for any endpoint, etc.

    @notification_rooms = /^\w+:/

The host rooms
--------------

Host buses are targetted towards internal CCNQ hosts.
They are accessible on the public API, currently only to admins.

    @host_buses = [
      'dial_calls'    # towards exultant-songs
      'locations'     # towards ccnq4-opensips
      'traces'        # towards nifty-ground
    ]

The private rooms
-----------------

Private buses are accessible on the public API and require some level of authentication + admin access.
Messages coming from the internal CCNQ hosts are forwarded to those buses. This will be a lot of messages on a normal system.
Each bus/room will receive specific messages, this allows to somewhat restrict the volume of messages received.

    @private_buses = [
      'calls'
      'internal'
      'support'
    ]
