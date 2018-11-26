# hiera_aws_secretsmanager

#### Table of Contents

1. [Description](#description)
1. [Setup - The basics of getting started with hiera_aws_secretsmanager](#setup)
    * [What hiera_aws_secretsmanager affects](#what-hiera_aws_secretsmanager-affects)
    * [Setup requirements](#setup-requirements)
    * [Beginning with hiera_aws_secretsmanager](#beginning-with-hiera_aws_secretsmanager)
1. [Usage - Configuration options and additional functionality](#usage)
1. [Reference - An under-the-hood peek at what the module is doing and how](#reference)
1. [Limitations - OS compatibility, etc.](#limitations)
1. [Development - Guide for contributing to the module](#development)

## Description

Provides a Hiera 5 `lookup_key` function for AWS Secrets Manager.

## Setup

### Setup Requirements

Requires the `aws-sdk-secretsmanager` gem:

``` shell
/opt/puppetlabs/puppet/bin/gem install aws-sdk-secretsmanager
```

or

``` puppet
package { 'aws-sdk-secretsmanager':
  ensure   => 'present',
  provider => 'puppet',
}
```


## Usage

### Authentication

Auth is expected to be taken care of outside of Puppet. There are
multiple ways to do this, anything accepted by the AWS SDK should work.

* AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY
* $HOME/.aws/credentials
* Instance Profile Credentials

Add to `hiera.yaml`:

``` yaml
---
version: 5

hierarchy:
  - name: AWS Secrets Manager
    lookup_key: hiera_aws_secretsmanager
	uris:
	  - /secrets/${::environment}/
```

Then `lookup('myapp::database::password'` will find,
e.g. `/secrets/development/myapp::database::password` in Secrets
Manager and return its `secret_string` attribute.

## Limitations

Only tested on our (Salesforce DMP) own infrastructure so far.

Only returns `secret_string`. There is no way to return
`secret_binary` or any other attribute from the secret.
