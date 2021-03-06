
normalize = require '../../lib/config/normalize'
params = require '../../lib/params'
fs = require 'fs'
nikita = require 'nikita'
parameters = require 'parameters'

describe 'command graph', ->

  tmp = '/tmp/masson-test'
  beforeEach ->
    require('module')._cache = {}
    nikita
    .system.mkdir target: tmp
    .promise()
  afterEach ->
    nikita
    .system.remove tmp
    .promise()

  it 'no arguments', ->
    write = process.stdout.write
    data = null
    process.stdout.write = (d)->
      data = d
    fs.writeFileSync "#{tmp}/a.json", JSON.stringify {}
    config = normalize
      clusters: 'cluster_a': services:
        'dep_a':
          module: "#{tmp}/a"
          options: 'key': 'value'
        'service_a':
          module: "#{tmp}/a"
          deps: 'my_dep_a': module: "#{tmp}/dep_a", local: true
    parameters(params).route(['graph', '-f', 'json'], config)
    process.stdout.write = write
    JSON.parse(data).should.eql [
      'cluster_a:dep_a'
      'cluster_a:service_a'
    ]

  it 'with nodes, JSON format', ->
    write = process.stdout.write
    data = null
    process.stdout.write = (d)->
      data = d
    fs.writeFileSync "#{tmp}/a.json", JSON.stringify {}
    config = normalize
      clusters: 'cluster_a': services:
        'dep_a':
          module: "#{tmp}/a"
          affinity: type: 'nodes', values: 'b.fqdn'
          options: 'key': 'value'
        'service_a':
          module: "#{tmp}/a"
          affinity: type: 'nodes', values: 'a.fqdn'
          deps: 'my_dep_a': module: "#{tmp}/dep_a", local: true
      nodes:
        'a.fqdn': true
        'b.fqdn': true
    parameters(params).route(['graph', '--nodes', '-f', 'json'], config)
    process.stdout.write = write
    JSON.parse(data).should.eql [
      cluster: 'cluster_a'
      id: 'dep_a'
      module: "#{tmp}/a"
      nodes: ['b.fqdn']
    ,
      cluster: 'cluster_a'
      id: 'service_a'
      module: "#{tmp}/a"
      nodes: ['a.fqdn']
    ]

  it 'with nodes, human format', ->
    write = process.stdout.write
    data = ''
    process.stdout.write = (d)->
      data += d
    fs.writeFileSync "#{tmp}/dep_a.json", JSON.stringify {}
    fs.writeFileSync "#{tmp}/a.json", JSON.stringify {}
    config = normalize
      clusters: 'cluster_a': services:
        "#{tmp}/dep_a":
          affinity: type: 'nodes', values: 'b.fqdn'
          options: 'key': 'value'
        'service_a':
          module: "#{tmp}/a"
          affinity: type: 'nodes', values: 'a.fqdn'
          deps: 'my_dep_a': module: "#{tmp}/dep_a", local: true
      nodes:
        'a.fqdn': true
        'b.fqdn': true
    parameters(params).route(['graph', '--nodes'], config)
    process.stdout.write = write
    data.substr(-2, 2).should.eql '\n\n'
    data.trim().should.eql """
    * cluster_a:#{tmp}/dep_a
      * b.fqdn
    
    * cluster_a:service_a (#{tmp}/a)
      * a.fqdn
    """
