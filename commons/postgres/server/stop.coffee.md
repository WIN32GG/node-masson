
# PostgreSQL Server Stop

PostgreSQL Server is started through service command.Which is wrapper around 
the docker container.

    module.exports = header: 'PostgreSQL Server Stop', handler: ->
      @service.stop
        name: 'postgres-server'
