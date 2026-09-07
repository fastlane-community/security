# Security

[![CI](https://github.com/fastlane-community/security/actions/workflows/ci.yml/badge.svg)](https://github.com/fastlane-community/security/actions/workflows/ci.yml)
[![Gem](https://img.shields.io/gem/v/security.svg?style=flat)](https://rubygems.org/gems/security)
[![License](https://img.shields.io/badge/license-MIT-green.svg?style=flat)](https://github.com/fastlane-community/security/blob/main/LICENSE.md)

**A library for interacting with the macOS Keychain**

> This library provides only a subset of `security` subcommands,
> and is not intended for general use.

## Usage

```ruby
require 'security'

Security::Keychain.default_keychain.filename #=> "/Users/jappleseed/Library/Keychains/login.keychain-db"

item = Security::InternetPassword.find(server: "itunesconnect.apple.com")
item&.password #=> "p4ssw0rd"
```

## Keychains

`find`, `add` and `delete` all take an optional `keychain:`, naming the keychain
to act on. It accepts a `Security::Keychain` or a path. Without one, `security`
adds to the default keychain and searches the default search list.

```ruby
keychain = Security::Keychain.new("/path/to/build.keychain-db")

Security::InternetPassword.add("example.com", "jappleseed", "p4ssw0rd", keychain: keychain)
Security::InternetPassword.find(server: "example.com", keychain: keychain)
Security::InternetPassword.delete(server: "example.com", keychain: keychain)
```

## Errors

The `security` command line tool reports failures through its exit status, and
this library distinguishes the two cases a caller needs to tell apart:

- **Nothing matched.** `find` returns `nil`. The keychain answered, and it holds
  no such item.
- **The question could not be answered.** `find` raises `Security::Error`,
  carrying the tool's exit `status` and its `output`. A locked keychain, a
  keychain this process is not allowed to read, or a malformed request all
  land here.

```ruby
begin
  item = Security::InternetPassword.find(server: "itunesconnect.apple.com")
rescue Security::Error => e
  warn "could not read the keychain: #{e.message}"
  item = nil
end
```

`Keychain.list`, `Keychain.default_keychain` and `Keychain.login_keychain`
raise `Security::Error` on failure in the same way.

The methods that change the keychain — `add`, `delete`, and the `Keychain`
instance methods — return `true` or `false` and print what the tool reported,
the way `Kernel#system` does.

## License

[MIT](https://github.com/fastlane-community/security/blob/main/LICENSE.md)
