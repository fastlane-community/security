# Security

[![Build Status][build status badge]][build status]

**A library for interacting with the macOS Keychain**

> This library provides only a subset of `security` subcommands,
> and is not intended for general use.

## Usage

```ruby
Security::Keychain::default_keychain.filename #=> "/Users/jappleseed/Library/Keychains/login.keychain"

Security::InternetPassword.find(server: "itunesconnect.apple.com").password #=> "p4ssw0rd"
```

## License

MIT

[build status]: https://github.com/mattt/Security/actions?query=workflow%3ACI
[build status badge]: https://github.com/mattt/Security/workflows/CI/badge.svg
