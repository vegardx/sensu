Sensu Cookbook
=================

A simpler and easier to maintain cookbook for Sensu.

Requirements
------------

### Platform:

* Debian 7

### Cookbooks:

* apt

### Other:

I should document this better.

Attributes
----------

None.

Recipes
-------

### sensu::default

Install Sensu, but do not configure. 

### sensu::server

Install and configure Sensu server, rabbitmq and redis.

### sensu::client

Configure Sensu client and connect to a Sensu server
