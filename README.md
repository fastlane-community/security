# Security

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
