<p align="center">
  <img width="400" alt="Parcelvoy Logo" src=".github/assets/logo-light.png#gh-light-mode-only" />
  <img width="400" alt="Parcelvoy Logo" src=".github/assets/logo-dark.png#gh-dark-mode-only" />
</p>

# Parcelvoy iOS SDK

## Version Information
- The Parcelvoy iOS SDK supports
  - iOS 12.0+
  - Mac Catalyst 13.0+
- Xcode 13.2.1 (13C100) or newer

## Installation
Installing the Parcelvoy iOS SDK will provide you with basic tracking functionality and user identification. The iOS SDK is available through either:
- Swift Package Manager
- CocoaPods

## Usage
### Initialize
Before using any methods, the library must be initialized with an API key and URL endpoint. 

Start by importing the Parcelvoy SDK:
```swift
import Parcelvoy
```

Then you can initialize the library:
```swift
Parcelvoy.initialize(apiKey: "API_KEY", urlEndpoint: "URL_ENDPOINT")
```

### Identify
You can handle the user identity of your users by using the `identify` method. This method works in combination either/or associate a given user to your internal user ID (`external_id`) or to associate attributes (traits) to the user. By default all events and traits are associated with an anonymous ID until a user is identified with an `external_id`. From that point moving forward, all updates to the user and events will be associated to your provider identifier.
```swift
Parcelvoy.shared.identify(id: "USER_ID", traits: [
    "first_name": "John",
    "last_name": "Doe"
])
```

### Events
If you wnat to trigger journey and list updates off of things a user does within your app, you can pass up those events by using the `track` method.
```swift
Parcelvoy.shared.track(
    event: "Event Name",
    properties: [
        "Key": "Value"
    ]
)

### Register Device
In order to send push notifications to a given device you need to register for notifications and then register the device with Parcelvoy. You can do so by using the `register(token: Data?)` method. If a user does not grant access to send notifications, you can also call this method without a token to register device characteristics.
```swift
Parcelvoy.shared.register(token: "APN_TOKEN_DATA")
```

## Example

Explore our [example project](/Example) which includes basic usage.

