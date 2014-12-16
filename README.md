# UUID Prefix

This is a Sequel Model plugin that adds [0-9a-z] unique ID prefixed by a custom string.

The prefix isn't stored in the database. Only the Unique ID itself is.

Usage:

```ruby
class Account < Sequel::Model
  plugin Sequel::Plugins::UUIDPrefix

  uuid_prefix 'a'
end

class User < Sequel::Model
  plugin Sequel::Plugins::UUIDPrefix

  uuid_prefix 'u'
end

# Find an account.
UUIDPrefix.find('a-xxxxxxxx')

# Find a user.
UUIDPrefix.find('u-xxxxxxxx')

user1.uuid_prefix # == 'u'
user1.canonical_uuid # == 'u-abcd1234'

Account['a-xxxxyyyy'] # Returns the account with UUID a-xxxxyyyy

Account.trim_uuid('a-abcd1234') # == 'abcd1234'
```
