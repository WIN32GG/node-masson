
# Kerberos Server Status

Check if the kadmin and krb5kdc daemons are running.

    module.exports = header: 'Kerberos Server Status', handler: ->
      @service.status
        header: 'kadmin'
        name: 'kadmin'
      @service.status
        header:'krb5kdc'
        name:'krb5kdc'
