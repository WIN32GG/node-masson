
# OpenLDAP Server Install

The default ports used by OpenLdap server are 389 and 636.

todo: add migrationtools

    module.exports = header: 'OpenLDAP Server Install', handler: (options) ->
      {openldap_server} = @config

## IPTables

| Service    | Port | Proto     | Parameter       |
|------------|------|-----------|-----------------|
| slapd      | 389  | tcp/ldap  | -               |
| slapd      | 636  | tcp/ldaps | -               |

IPTables rules are only inserted if the parameter "iptables.action" is set to
"start" (default value).

      @tools.iptables
        header: 'IPTables'
        rules: [
          { chain: 'INPUT', jump: 'ACCEPT', dport: 389, protocol: 'tcp', state: 'NEW', comment: "LDAP (non-secured)" }
          { chain: 'INPUT', jump: 'ACCEPT', dport: 636, protocol: 'tcp', state: 'NEW', comment: "LDAP (secured)" }
        ]
        if: @has_service('masson/core/iptables') and @config.iptables.action is 'start'

## Users & Groups

By default, the "openldap-servers" package create the following entries:

```bash
cat /etc/passwd | grep ldap
ldap:x:55:55:LDAP User:/var/lib/ldap:/sbin/nologin
cat /etc/group | grep ldap
ldap:x:55:
```

      @call header: 'User & Group', ->
        @system.group openldap_server.group
        @system.user openldap_server.user

## Packages

      @call header: 'Service', ->
        @service
          name: 'openldap-servers'
          chk_name: 'slapd'
          startup: true
        @service
          name: 'openldap-clients'
        @service
          name: 'migrationtools'
        @system.discover (err, status, os) ->
          @system.tmpfs
            if: -> (os.type in ['redhat','centos']) and (os.release[0] is '7')
            mount: '/var/run/openldap'
            name: 'openldap'
            uid: openldap_server.user.name
            gid: openldap_server.group.name
            perm: '0750'
        @service.start 'slapd'

## Logging

http://joshitech.blogspot.fr/2009/09/how-to-enabled-logging-in-openldap.html

      @call header: 'Logging', handler: (options) ->
        options.log 'Check rsyslog dependency'
        @service
          name: 'rsyslog'
        options.log 'Declare local4 in rsyslog configuration'
        @file
          target: '/etc/rsyslog.conf'
          match: /^local4.*/mg
          replace: 'local4.* /var/log/slapd.log'
          append: 'RULES'
        options.log 'Restart rsyslog service'
        @service
          name: 'rsyslog'
          action: 'restart'
          if: -> @status -1
        @system.execute
          unless_exec: """
          ldapsearch -Y EXTERNAL -H ldapi:/// -b "cn=config" \
          | grep -E "olcLogLevel: #{openldap_server.log_level}"
          """
          cmd: """
          ldapmodify -Y EXTERNAL -H ldapi:/// <<-EOF
          dn: cn=config
          changetype: modify
          replace: olcLogLevel
          olcLogLevel: #{openldap_server.log_level}
          EOF
          """

## Import Basic Schema
On Redhat/Centos 7, Basic schema must be manually imported.
Check section[3](https://www.server-world.info/en/note?os=CentOS_7&p=openldap).

      @system.execute (
        header: "Import Schema #{schema}"
        cmd: "ldapadd -Y EXTERNAL -H ldapi:/// -f /etc/openldap/schema/#{schema}.ldif"
        unless_exec: """
        ldapsearch -Y EXTERNAL -H ldapi:/// \
          -b "cn=schema,cn=config" \
        | grep -E cn=\{[0-9]+\}#{schema},cn=schema,cn=config
        """
      ) for schema in ['cosine','inetorgperson','nis']

## Database config

Borrowed from:
* http://docs.adaptivecomputing.com/viewpoint/hpc/Content/topics/1-setup/installSetup/settingUpOpenLDAPOnCentos6.htm
Interesting posts also include:
* http://itdavid.blogspot.ca/2012/05/howto-centos-6.html
* http://www.6tech.org/2013/01/ldap-server-and-centos-6-3/

      @call header: 'Database config', handler: (options) ->
        @system.execute
          header: 'Root DN'
          unless_exec: """
          ldapsearch -Y EXTERNAL -H ldapi:/// -b "olcDatabase={0}config,cn=config" \
          | grep -E "olcRootDN: #{openldap_server.config_dn}"
          """
          cmd: """
          ldapmodify -Y EXTERNAL -H ldapi:/// <<-EOF
          dn: olcDatabase={0}config,cn=config
          changetype: modify
          replace: olcRootDN
          olcRootDN: #{openldap_server.config_dn}
          EOF
          """
        @call (_, callback) -> @system.execute
          cmd: 'ldapsearch -Y EXTERNAL -H ldapi:/// -b "olcDatabase={0}config,cn=config"'
        , (err, _, stdout) ->
          return callback err if err
          if match = /^olcRootPW: {SSHA}(.*)$/m.exec stdout
            callback null, not check_password openldap_server.config_password, match[1]
          else # First installation, password not yet defined
            callback null, true
        @system.execute
          header: 'Root PW'
          if: -> @status -1
          cmd: """
          password=`slappasswd -s #{openldap_server.config_password}`
          ldapmodify -c -Y EXTERNAL -H ldapi:/// <<-EOF
          dn: olcDatabase={0}config,cn=config
          changetype: modify
          replace: olcRootPW
          olcRootPW: $password
          EOF
          """
        @service.restart 'slapd', if: -> @status -1

## DB monitor root DN

Usage and configuration of OpenLDAP monitoring is not clear, commented for now.

      # @file
      #   header: 'DB monitor root DN'
      #   target: openldap_server.monitor_file
      #   match: /^(.*)dc=my-domain,dc=com(.*)$/m
      #   replace: "$1#{openldap_server.suffix}$2"

## Database hdb

The path of the bdb configuration file differ between RH6 and RH7. It is
discovered at runtime based on the OS release.

      @call header: 'DB bdb', handler: (options) ->
        bdb = null
        @system.discover shy: true, (err, status, info) ->
          throw Error "Unsupported OS: #{JSON.stringify info.type}" unless info.type in ['centos', 'redhat']
          bdb = if /^6/.test info.release then 'bdb' else 'hdb'
        @call ->
          @system.execute
            header: 'Suffix'
            unless_exec: """
            ldapsearch -Y EXTERNAL -H ldapi:/// \
              -b "olcDatabase={2}#{bdb},cn=config" \
            | grep -E "olcSuffix: #{openldap_server.suffix}"
            """
            cmd: """
            ldapmodify -Y EXTERNAL -H ldapi:/// <<-EOF
            dn: olcDatabase={2}#{bdb},cn=config
            changetype: modify
            replace: olcSuffix
            olcSuffix: #{openldap_server.suffix}
            EOF
            """
          @system.execute
            header: 'Root DN'
            unless_exec: """
            ldapsearch -Y EXTERNAL -H ldapi:/// \
              -b "olcDatabase={2}#{bdb},cn=config" \
            | grep -E "olcRootDN: #{openldap_server.root_dn}"
            """
            cmd: """
            ldapmodify -Y EXTERNAL -H ldapi:/// <<-EOF
            dn: olcDatabase={2}#{bdb},cn=config
            changetype: modify
            replace: olcRootDN
            olcRootDN: #{openldap_server.root_dn}
            EOF
            """
          @call (_, callback) ->  @system.execute
            cmd: "ldapsearch -Y EXTERNAL -H ldapi:/// -b 'olcDatabase={2}#{bdb},cn=config'"
          , (err, _, stdout) ->
            return callback err if err
            if match = /^olcRootPW: {SSHA}(.*)$/m.exec stdout
              callback null, not check_password openldap_server.root_password, match[1]
            else # First installation, password not yet defined
              callback null, true
          @system.execute
            header: 'Root PW'
            if: -> @status -1
            cmd: """
            password=`slappasswd -s #{openldap_server.root_password}`
            ldapmodify -c -Y EXTERNAL -H ldapi:/// <<-EOF
            dn: olcDatabase={2}#{bdb},cn=config
            changetype: modify
            replace: olcRootPW
            olcRootPW: $password
            EOF
            """
          @service.restart 'slapd', if: -> @status -1

## ACLs

ACLs can be retrieved with the command:

`ldapsearch -LLL -Y EXTERNAL -H ldapi:/// -b "cn=config" '(olcAccess=*)'`

      @call header: "ACLs", handler: (options) ->
        # We used: http://itdavid.blogspot.fr/2012/05/howto-centos-62-kerberos-kdc-with.html
        # But this is also interesting: http://web.mit.edu/kerberos/krb5-current/doc/admin/conf_ldap.html
        # says that a user with the group id and user id of 0 (root), matched using EXTERNAL SASL on localhost
        @ldap.acl
          header: 'Global Rules'
          suffix: openldap_server.suffix
          acls: [
            to: 'attrs=userPassword,userPKCS12'
            by: [
              'dn.base="gidNumber=0+uidNumber=0,cn=peercred,cn=external,cn=auth" manage'
              'self write'
              'anonymous auth'
              '* none'
            ]
          ,
            to: 'attrs=shadowLastChange'
            by: [
              'dn.base="gidNumber=0+uidNumber=0,cn=peercred,cn=external,cn=auth" manage'
              'self write'
              '* none'
            ]
          ]

## Users and Groups

      [_, suffix_k, suffix_v] = /(\w+)=([^,]+)/.exec openldap_server.suffix
      @system.execute
        header: 'Users and Groups'
        cmd: """
        ldapadd -c -H ldapi:/// -D #{openldap_server.root_dn} -w #{openldap_server.root_password} <<-EOF
        dn: #{openldap_server.suffix}
        #{suffix_k}: #{suffix_v}
        objectClass: top
        objectClass: domain

        dn: #{openldap_server.users_dn}
        ou: Users
        objectClass: top
        objectClass: organizationalUnit
        description: Central location for UNIX users

        dn: #{openldap_server.groups_dn}
        ou: Groups
        objectClass: top
        objectClass: organizationalUnit
        description: Central location for UNIX groups
        EOF
        """
        code_skipped: 68
      # @ldap.acl
      #   header: 'ACL'
      #   suffix: openldap_server.suffix
      #   acls: [
      #     to: 'dn.subtree=#{openldap_server.users_dn}'
      #     by: [
      #       'dn.children="#{openldap_server.users_dn}" read'
      #     ]
      #   ]


## Sudo Schema

      @call header: 'SUDO schema', handler: ->
        @service
          name: 'sudo'
        schema = '/tmp/ldap.schema'
        @system.execute
          cmd: """
          schema=`rpm -ql sudo | grep -i schema.openldap`
          if [ ! -f $schema ]; then exit 2; fi
          echo $schema
          """
          code_skipped: 2
          shy: true
        , (err, exists, stdout) ->
          schema = stdout.trim() if exists
        @file.download
          source: "#{__dirname}/resources/ldap.schema"
          target: '/tmp/ldap.schema'
          mode: 0o0640
          unless: -> @status -1
        @call -> @ldap.schema
          name: 'sudo'
          schema: schema
          binddn: openldap_server.config_dn
          passwd: openldap_server.config_password
          uri: true

## Delete ldif data

      @call header: 'Delete ldif data', handler: ->
        for path in openldap_server.ldapdelete
          target = "/tmp/ryba_#{Date.now()}"
          @file.download
            source: path
            target: target
            mode: 0o0640
          @system.execute
            cmd: "ldapdelete -c -Y EXTERNAL -H ldapi:/// -f #{target}"
            code_skipped: 32
          @system.remove
            target: target

## Add ldif data

      @call header: 'Add ldif data', handler: ->
        status = false
        for path in openldap_server.ldapadd
          target = "/tmp/ryba_#{Date.now()}"
          @file.download
            source: path
            target: target
            shy: true
          @system.execute
            cmd: "ldapadd -c -Y EXTERNAL -H ldapi:/// -f #{target}"
            code_skipped: 68
            shy: true
          , (err, executed, stdout, stderr) ->
            return if err
            status = true if stdout.match(/Already exists/g)?.length isnt stdout.match(/adding new entry/g).length
          @system.remove
            target: target
            shy: true
        @call (_, callback) ->
          callback null, status

## Exported functions

    check_password = (password, shahash) ->
      buf = new Buffer shahash, 'base64'
      hash = (new Buffer shahash, 'base64').slice 0, 20
      salt = (new Buffer shahash, 'base64').slice 20, 24
      return hash.toString('base64') is crypto
      .createHash('sha1')
      .update(password)
      .update(salt)
      .digest('base64')

## Module Dependencies

    crypto = require 'crypto'

## Useful commands

```bash
# Search from local:
ldapsearch -LLLY EXTERNAL -H ldapi:/// -b cn=schema,cn=config dn

# Search from remote:
ldapsearch -x -LLL -H ldap://master3.hadoop:389 -D cn=Manager,dc=ryba -w test -b "dc=ryba" "objectClass=*"
ldapsearch -x -H ldaps://master3.hadoop:636 -D cn=Manager,dc=ryba -w test -b dc=ryba
ldapsearch -D cn=admin,cn=config -w test -d 1 -b "cn=config"
ldapsearch -D cn=Manager,dc=ryba -w test -b "dc=ryba"
ldapsearch -ZZ -d 5 -D cn=Manager,dc=ryba -w test -b "dc=ryba"

# Check configuration with debug information:
slaptest -v -d5 -u

# Change user password:
ldappasswd -xZWD cn=Manager,dc=ryba -S cn=wdavidw,ou=users,dc=ryba
```

Enable ldapi:// access to root on our ldap tree
  vi /etc/openldap/slapd.d/cn=config/olcDatabase={2}bdb.ldif
  # Add new olcAccess rule
  > olcAccess: {0}to *  by dn.base="gidNumber=0+uidNumber=0,cn=peercred,cn=externa
  > l,cn=auth" manage  by * none
  ldapsearch -LLLY EXTERNAL -H ldapi:/// -b dc=ryba

Resources:

*   [How to fix "ldif_read_file: checksum error"](http://injustfiveminutes.com/2014/10/28/how-to-fix-ldif_read_file-checksum-error/)
*   [script with just about everything](http://serverfault.com/questions/323497/how-do-i-configure-ldap-on-centos-6-for-user-authentication-in-the-most-secure-a)
