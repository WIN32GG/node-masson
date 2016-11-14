
# System Install

    module.exports = header: 'System Install', handler: ->
      {system} = @config

## SELinux

Security-Enhanced Linux (SELinux) is a mandatory access control (MAC) security 
mechanism implemented in the kernel.

This action update the configuration file present in "/etc/selinux/config". The
OS will reboot if SELINUX was modified.

      @file
        header: 'SELinux'
        target: '/etc/selinux/config'
        match: /^SELINUX=.*/mg
        replace: "SELINUX=#{if system.selinux then 'enforcing' else 'disabled'}"
      @execute
        header: 'Reboot'
        cmd: 'shutdown -r now'
        if: -> @status -1

## Limits

On CentOs 6.4, The default values are:

```bash
cat /etc/security/limits.conf
*                -    nofile          8192
cat /etc/security/limits.d/90-nproc.conf
*          soft    nproc     1024
root       soft    nproc     unlimited
```

      @file (
        header: "Limits on #{filename}"
        target: "/etc/security/limits.d/#{filename}"
        content: content
        backup: true
      ) for filename, content of system.limits

## Groups

Create the users defined inside the "hdp.groups" configuration. See the
[mecano "group" documentation][mecano_group] for additionnal information.

      @call header: 'Groups', ->
        @group group for _, group of system.groups

## Users

Create the users defined inside the "hdp.users" configuration. See the
[mecano "user" documentation][mecano_user] for additionnal information.
        
      @call header: 'Users', ->
        @user user for _, user of system.users

## Profile

Publish scripts inside the profile directory, located in "/etc/profile.d".
      
      @call header: 'Profile', ->
        @file (
          target: "/etc/profile.d/#{filename}"
          content: content
          eof: true
        ) for filename, content of @config.profile

[mecano_group]: https://github.com/wdavidw/node-mecano/blob/master/src/group.coffee.md
[mecano_user]: https://github.com/wdavidw/node-mecano/blob/master/src/user.coffee.md