Multiple-backends interface for the generic case
================================================

      make_proxy = require './make_proxy'

      module.exports = make_plain_proxy = (bases...) ->
        proxy = make_proxy bases...
        ->
          proxy.call this, @request.headers
