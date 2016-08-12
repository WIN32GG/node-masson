# PostgreSQL

PostgreSQL is a powerful, open source object-relational database system. 
It has more than 15 years of active development and a proven architecture that
has earned it a strong reputation for reliability, data integrity, and correctness.
It is fully ACID compliant, has full support for foreign keys, joins, views, triggers,
 and stored procedures (in multiple languages). 
```
./bin/prepare
```


    module.exports = -> 
      'configure': [
        'masson/commons/postgres/server/configure'
      ]
      'install': [
        'masson/core/iptables'
        'masson/commons/postgres/server/install'
        'masson/commons/postgres/server/start'
        'masson/commons/postgres/server/check'
      ]
      'prepare': [
        'masson/commons/postgres/server/prepare'
      ]