
# Kerberos Server Backup

    module.exports = name: "Kerberos Server Backup", label_true: 'BACKUPED', handler: (options) ->
      @tools.backup
        header: 'Database'
        name: 'kerberos'
        cmd: 'kdb5_util dump'
