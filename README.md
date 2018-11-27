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

* `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` envvars
* `$HOME/.aws/credentials`
* [https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_use_switch-role-ec2_instance-profiles.html](Instance Profile Credentials)

### Authorization

The requesting entity will need the following privilege.

Restricting `secretsmanager:GetSecretValue` to some prefix in your
Secrets Manager naming scheme is recommended.

As of 2018-11-26, `secretsmanager:ListSecrets` is all or nothing. It
can not be restricted to a prefix.

``` json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowPuppetSecrets",
      "Effect": "Allow",
      "Action": "secretsmanager:GetSecretValue",
      "Resource": "arn:aws:secretsmanager:*:*:secret:puppet/*"
    },
    {
      "Sid": "AllowListAllSecrets",
      "Effect": "Allow",
      "Action": "secretsmanager:ListSecrets",
      "Resource": "*"
    }
  ]
}
```

### Configuration

Add to `hiera.yaml`:

``` yaml
---
version: 5

hierarchy:
  - name: AWS Secrets Manager
    lookup_key: hiera_aws_secretsmanager
    uris:
      - secrets/${::environment}/
    options:
      region: us-east-1
```

Then `lookup('myapp::database::password')` will find,
e.g. `secrets/development/myapp::database::password` in Secrets
Manager and return its `secret_string` attribute.

#### Notes

1. Paths in Secrets Manager may not have a leading `/`.
2. Getting `$AWS_REGION` set in the context of the catalog compile
   turns out to be a pain, so the `region` option is required for now.

### Caching

In order to conserve API calls (which are not free), lookup will list
and cache all secret names on first execution, as well any secrets
fetched. This is why `secretsmanager:ListSecrets` privilege is
required.

## Limitations

Only tested on our (Salesforce DMP) own infrastructure so far.

Only returns `secret_string`. There is no way to return
`secret_binary` or any other attribute from the secret.

There is no way to skip caching of secret names.
