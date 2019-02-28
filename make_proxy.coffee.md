    request = require 'request'

    make_proxy = (bases...) ->

      if bases[0]? and Array.isArray bases[0]
        bases = bases[0]

      (headers) ->

Report error to the next middleware.

        report = (error) =>
          throw new Error "Report: #{error}"

Failover
========

        failover = (index,error) =>

Note: The error may be `null` or irrelevant.

We keep going until we run out of backends to query.

          unless index < bases.length
            report error
            return

          base = bases[index]
          index++

Skip `null` entries

          unless base?
            failover index, error
            return

          url = "#{base}#{@request.url}"

          if index < bases.length
            timeout = module.exports.timeout
          else
            timeout = module.exports.last_timeout

          proxy = request
            method: @request.method
            url: url
            headers: headers  # .set headers
            followRedirects: false # .redirects 0
            maxRedirects: 0
            strictSSL: false # .agent false
            timeout: timeout

Initial request attempt to the first backed: pipe the request to the server.
In case of error (assuming network error, hence the request was not piped yet), attempt to pipe to the failover server (if any).

          @request.pipe proxy
          .on 'error', (error) ->
            failover index, error

Pipe the response back to the client.

          proxy.pipe @response

We do not catch errors on the response: it's too late anyhow.

          return

        failover 0, new Error 'No backend available'
        return

    module.exports = make_proxy
    integer = (n) ->
      v =parseInt n, 10
      if isNaN v then null else v
    module.exports.timeout = (integer process.env.TIMEOUT) ? 2000
    module.exports.last_timeout = (integer process.env.LAST_TIMEOUT) ? 100000
