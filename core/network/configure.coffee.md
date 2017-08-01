
# Network Configure

## Options

The module accept the following properties:

*   `hostname` (boolean)   
    The server hostname as return by the command "hostname" and defined by the 
    property "HOSTNAME" inside the "/etc/sysconfig/network" file, must not be 
    configure globally, default to the "host" property.   
*   `network.hostname_disabled` (boolean)   
    Do not update the hostname, disable the effect of the
    "hostname" property (which itself default to "host"), 
    default to "false".   
*   `network.hosts_auto` (boolean)   
    Enrich the "/etc/hosts" file with the server hostname present on 
    the cluster, default to "false"   
*   `network.hosts` (object)   
    Enrich the "/etc/hosts" file with custom adresses, the keys represent the 
    IPs and the value the hostnames, optional.   
*   `network.resolv` (string)   
    Content of the '/etc/resolv.conf' file, optional.   
*   `network.host_replace` (string)   
    Custom hostname to replace in /etc/hosts, optional.   

## Default configuration

```json
{ "network": {
  "hostname_disabled": false,
  "hosts_auto": false,
} }
```

## Example

```json
{ "network": {
    "hosts_auto": true,
    "hosts": {
      "10.10.10.15": "myserver.hadoop"
    },
    "resolv": "search hadoop\nnameserver 10.10.10.16\nnameserver 10.0.2.3"
    "ifcfg": {
      "eth0": {
        "PEERDNS": "no"
      }
    },
    "host_replace": {
      "10.10.10.11": "master1.new.ryba",
      "10.10.10.12": "master2.new.ryba",
      "10.10.10.13": "master3.new.ryba"
    }
} }
```

    module.exports = ->
      @config.hostname ?= @config.host
      @config.shortname ?= @config.host.split('.')[0]
      options = @config.network ?= {}
      options.hostname_disabled ?= false
      options.hosts_auto ?= false
      # for host, server of @config.servers
      #   server.shortname ?= server.host.split('.')[0]
