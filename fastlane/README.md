fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## iOS

### ios load_asc_api_key

```sh
[bundle exec] fastlane ios load_asc_api_key
```

Load App Store Connect API key from environment

### ios sync_certificates

```sh
[bundle exec] fastlane ios sync_certificates
```

Sync certificates and provisioning profiles via match

### ios revoke_distribution

```sh
[bundle exec] fastlane ios revoke_distribution
```

Revoke this account's iOS distribution certificates (each app has its own Apple account)

### ios bump_build_number

```sh
[bundle exec] fastlane ios bump_build_number
```

Increment build number based on latest TestFlight build

### ios build_ipa

```sh
[bundle exec] fastlane ios build_ipa
```

Build + package the .ipa without uploading to App Store

### ios release

```sh
[bundle exec] fastlane ios release
```

Build and upload to App Store

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
