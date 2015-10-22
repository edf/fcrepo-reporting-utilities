#fcrepo-reporting-utilities

## Description

Utilities for generating reports about a Fedora Repository:

- space used by a collection
- objects created by fiscal year

## Requirements

* libxml-libxslt-perl: `sudo apt-get install libxml-libxslt-perl`
* XML::LibXSLT: `sudo cpanm XML::LibXSLT`
* Config::Tiny: `sudo cpanm Config::Tiny`

Copy `settings.sample` to `setting.config` and set variables.

## Usage

Determine disk space used by a given collection:

`perl reportSpaceUsedByCollection.pl collection:pid`

Determine the number of object created in a fiscal year:

`perl objectsCreatedByFiscalYear.pl > index.html`

## Sample ouput

```
$ perl reportSpaceUsedByCollection.pl yul:F0433

Collection yul:F0433 Totals

  Fedora Objects: 10489
  Space Used: 177.545 GB
  Number of Datastreams: 85485
```

## Quick way to get count of all Fedora Objects 

`curl -s "http://fedora:8080/solr/select?q=*:*&fl=*" | tidy -xml -wrap 0 2>/dev/null | grep numFound`

## Note

Communication is in the clear to the FCRepo server. We have protect our reporting and FCRepo servers behind a firewall. Your mileage will vary.
