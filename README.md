# Security

[![Build Status][build status badge]][build status]

**A library for interacting with the macOS Keychain**

> This library implements only the commands necessary for password management in
> [Cupertino](https://github.com/mattt/cupertino).
> As such, some methods are stubbed out to raise `NotImplementedError`.

## Usage

```ruby
Security::Keychain::default_keychain.filename #=> "/Users/jappleseed/Library/Keychains/login.keychain"

Security::InternetPassword.find(server: "itunesconnect.apple.com").password #=> "p4ssw0rd"
```

## License

MIT

## Contact

Mattt ([@mattt](https://twitter.com/mattt))

[build status]: https://github.com/mattt/Security/actions?query=workflow%3ACI
[build status badge]: https://github.com/mattt/Security/workflows/CI/badge.svg
