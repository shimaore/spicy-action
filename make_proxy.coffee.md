We do not currently use SuperAgent because it sets the transfer-encoding to chunked and the backend headers are not properly propagated.

      use_superagent = false

      if use_superagent
        request = (require 'superagent-as-promised') require 'superagent'
      else
        request = require 'request'

      module.exports = make_proxy = (bases...) ->
        (headers) ->

          report = (error) =>
            @next "Report: #{error}"
            return

          failover = (error) =>
            unless bases.length > 0
              report error
              return

            base = bases.shift()
            url = "#{base}#{@request.url}"
            if use_superagent
              proxy = request @request.method, url
                .set headers
                .agent false
                .redirects 0
                .timeout 1000

In case of error (assuming network error, hence the request was not piped yet), attempt to pipe to the failover server (if any).

              proxy.catch failover

            else
              proxy = request
                method: @request.method
                url: url
                headers: headers  # .set headers
                followRedirects: false # .redirects 0
                maxRedirects: 0
                strictSSL: false # .agent false
                timeout: 1000

Initial request attempt to the first backed: pipe the request to the server, pipe the response back to the client.

            @request.pipe proxy
            .on 'error', failover
            proxy.pipe @response
            .on 'error', failover
            return

          failover null
          return
