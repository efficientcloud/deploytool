# deploytool

Deployment tool for Platform-as-a-Service providers, with special support for multi-stage deploys (e.g. for staging environments).

Platforms currently supported:
* Heroku
* Cloud Foundry Platforms
* Efficient Cloud Platforms

## Deploying a Ruby on Rails app

    gem install deploytool
    deploy add production portfolio.heroku.com
    deploy add staging portfolio.vcap.me
    deploy production

## Config file

deploy keeps a local config file .deployrc within every top-level sourcecode directory (determined by location of .git directory).

## Legalese

_Copyright 2011, Efficient Cloud Ltd.

Released under the [MIT license](http://www.opensource.org/licenses/mit-license.php).
