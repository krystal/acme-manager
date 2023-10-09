# Acme Manager
This tool does management of LetsEncrypt certificates in our load balancer hosts. It does two main things:

### Web Server

It runs a webserver which allows certain apps to control certificates for domains externally. There are 3 API endpoints:

* `/~acmemanager/list` - lists all currently valid certificates with their expiry date
* `/~acmemanager/issue/example.com` - issues a certificate for example.com
* `/~acmemanager/purge/example.com` - purges a certificate for example.com

Requests must be authenticated by passing an API key in the X-API-KEY header.

### Bulk Certificate Renewals (CRON)

There's cron jobs set in the Load Balancer hosts (under the `haproxy` user) to run renewals daily at `02:00 AM`, the job looks like this:
```shell
0 2    * * * cd /opt/acme-manager; bundle exec ruby bin/renew.rb
```

The `misc` directory contains some scripts required for the High Availability setup in the Load Balancer hosts.

## Instructions
* Run bundle (or bundle --deployment for production)
* Copy config.rb.example to config.rb and configure as needed
* Make bin/setup.rb to generate master keys, create directories, and accept the LetsEncrypt TOS
* Run the web server with procodile `procodile start`
* Run bin/renew.rb from time to time
