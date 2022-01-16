# hiera_aws_secretsmanager

#### Table of Contents

1. [Description](#description)
1. [Setup - The basics of getting started with hiera_aws_secretsmanager](#setup)
    * [What hiera_aws_secretsmanager affects](#what-hiera_aws_secretsmanager-affects)
    * [Setup requirements](#setup-requirements)
    * [Beginning with hiera_aws_secretsmanager](#beginning-with-hiera_aws_secretsmanager)
1. [Usage - Configuration options and additional functionality](#usage)
    * [Notes](#notes)
    * [Retry/Backoff](#retrybackoff)
    * [StatsD](#statsd)
1. [Reference - An under-the-hood peek at what the module is doing and how](#reference)
1. [Limitations - OS compatibility, etc.](#limitations)
1. [Development - Guide for contributing to the module](#development)

## Description

An opinionated Hiera 5 `lookup_key` function for AWS Secrets Manager.

## Setup

### Setup Requirements

Requires the `aws-sdk-secretsmanager` gem:

```shell
/opt/puppetlabs/puppet/bin/gem install aws-sdk-secretsmanager
/opt/puppetlabs/server/bin/puppetserver gem install aws-sdk-secretsmanager
```

or

```puppet
package { 'aws-sdk-secretsmanager':
  ensure   => 'present',
  provider => 'puppet_gem',
}

package { 'aws-sdk-secretsmanager':
  ensure   => 'present',
  provider => 'puppetserver_gem',
}
```

If you want statsd reporting, then the Shopify/statsd-instrument gem is needed too:

```shell
/opt/puppetlabs/puppet/bin/gem install statsd-instrument -v '~> 3.0.1'
/opt/puppetlabs/server/bin/puppetserver gem install statsd-instrument -v '~> 3.0.1'
```

or

```puppet
package { 'statsd-instrument':
  ensure   => '~> 3.0.1',
  name     => 'statsd-instrument',
  provider => 'puppet_gem',
}

package { 'statsd-instrument-puppetserver':
  ensure   => '~> 3.0.1',
  name     => 'statsd-instrument',
  provider => 'puppetserver_gem',
  require  => Class['puppet']
}
```

### Installation

You can either clone this repository and include it in your puppet modules (named as `hiera_aws_secretsmanager`), or if you are using r10k,
add it to your puppetfile as:

```
mod 'hiera_aws_secretsmanager',
    :git => 'https://github.com/krux/hiera-aws-secretsmanager',
    :tag => 'v0.1.2'
```

### Authentication

Auth is expected to be taken care of outside of Puppet. There are
multiple ways to do this; anything accepted by the AWS SDK should work.

* `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` envvars
* `$HOME/.aws/credentials`
* [Instance Profile Credentials](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_use_switch-role-ec2_instance-profiles.html)

### Authorization

The requesting entity will need the following privilege.

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

Restricting `secretsmanager:GetSecretValue` to some prefix in your
Secrets Manager naming scheme is recommended.

As of 2018-11-26, `secretsmanager:ListSecrets` is all or nothing. It
can not be restricted to a prefix.

As of 2018-11-26, a leading `/` in the secret-id does not appear to
work.

### Convention

Some convention-over-configuration liberties have been
taken. Particularly:

#### Storing Secrets as JSON

The AWS Console and provided examples for rotation are both heavy on
JSON. This backend therefore assumes that the `secret_string` member
of your secret is always a valid JSON document, and that you want it
parsed. Conforming with RFC 7159, below are examples of valid strings
for the `SecretString` member:

``` json
"seekrit"

42

false

null

{ "username": "sooper", "password": "seekrit" }

[ 1, 2, 3 ]
```

Unquoted strings that are not values (like `true`) are not valid and
will raise a parse error. Be aware of the need for quoting in certain
contexts. E.g.

``` ruby
new_secret = "a string"
client.update_secret(secret_id: 'puppet/production/secret_key', secret_string: "\"#{new_secret}\"")
```
although much better in this instance would be
``` ruby
client.update_secret(secret_id: 'puppet/production/secret_key', secret_string: new_secret.to_json)
```

#### Character Translation In Secret Names

Secret IDs must be valid ARNs, which gives syntactical meaning to
`:`. In order to accomodate the Puppet convention of
`module::class::parameter`, whatever value you pass to `lookup()` have
`:` replaced by `=` before being looked up. Unfortunately this means
humans managing secrets will have to do this translation in wetware.

For a concrete example, assume a class definition like:

``` puppet
# module mymod
class myclass (
  String username,
  String password,
)
```

We would probably like to find `username` in our favorite Hiera
backend (let's just say YAML), and `password` in our secret
store. We can set this up with:

**data/environment/production/common.yaml:**
``` yaml
mymod::myclass::username: the_user
```

**tmp/secret.json:**
``` json
"the_password"
```

**create the secret:**
``` shell
aws secretsmanager create-secret --name puppet/production/mymod==myclass==password --secret-string file://tmp/secret.json
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
      - "secrets/%{::environment}"
    options:
      region: us-east-1
      statsd: true # optional
      retries: # optional
        retry_mode: adaptive
        max_attempts: 10
```

Then `lookup('myapp::database::password')` will find,
e.g. `secrets/development/myapp==database==password` in Secrets
Manager and return its `secret_string` attribute.

#### Notes

1. Paths in Secrets Manager may not have a leading `/`.
1. uris in the hiera configuration must not have a trailing `/`
1. Getting `$AWS_REGION` set in the context of the catalog compile
   turns out to be a pain, so the `region` option is required for now.

#### Retry/Backoff

It is possible to configure the AWS SDK retry/backoff by adding a
`options.retries` hash. Its value is passed to the AWS SDK with
minimal sanity checking. See the [Aws::SecretsManager::Client#initialize]
documentation for allowed values.

[Aws::SecretsManager::Client#initialize]: https://docs.aws.amazon.com/sdk-for-ruby/v3/api/Aws/SecretsManager/Client.html#initialize-instance_method

#### Endpoint

It is possible to configure the AWS SDK endpoint by adding a
`options.endpoint` hash. Its value is passed to the AWS SDK with
minimal sanity checking. See the [Aws::SecretsManager::Client#initialize]
documentation for allowed values.

[AWS PrivateLink] is a use case. Which is very convenience to privately connect
your VPC to supported AWS services, services hosted by other AWS accounts
(VPC endpoint services), and supported AWS Marketplace partner services.

[AWS PrivateLink]: https://docs.aws.amazon.com/vpc/latest/privatelink/endpoint-services-overview.html

#### StatsD

Setting `options.statsd: true` will enable some statsd reporting using
Shopify/statsd-instrument. If false or missing, no change in behavior
is expected.

### Caching

In order to conserve API calls (which are not free), lookup will list
and cache all secret names on first execution, as well any secrets
fetched. This is why `secretsmanager:ListSecrets` privilege is
required.

## Limitations

Only tested on our (Salesforce DMP) infrastructure so far.

There is no way to skip the initial caching of all secret names.

Only returns `secret_string`, which is unconditionally parsed as
JSON. There is no way to return `secret_binary` or any other attribute
from the secret, nor skip JSON parsing.

Secret names are unconditionally translated to replace `:` with `=`.

The `=` was chosen merely for visual similarity to `:` and is not
configurable.

The region option is the only way to set AWS Region and is required.

