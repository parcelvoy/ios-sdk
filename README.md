<p align="center">
  <img width="400" alt="Parcelvoy Logo" src=".github/assets/logo-light.png#gh-light-mode-only" />
  <img width="400" alt="Parcelvoy Logo" src=".github/assets/logo-dark.png#gh-dark-mode-only" />
</p>

# Parcelvoy iOS SDK

## Installation
Installing the Parcelvoy iOS SDK will provide you with user identification, deeplink unwrapping and basic tracking functionality. The iOS SDK is available through common package managers (SPM & Cocoapods) or through manual installation.

### Version Information
- The Parcelvoy iOS SDK supports
  - iOS 12.0+
  - Mac Catalyst 13.0+
- Xcode 13.2.1 (13C100) or newer

### Swift Package Manager
Go to File -> Swift Packages -> Add Package Dependency and enter:
```https://github.com/parcelvoy/ios-sdk```

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
If you want to trigger a journey and list updates off of things a user does within your app, you can pass up those events by using the `track` method.
```swift
Parcelvoy.shared.track(
    event: "Event Name",
    properties: [
        "Key": "Value"
    ]
)
```

### Notifications
#### Register Device
In order to send push notifications to a given device you need to register for notifications and then register the device with Parcelvoy. You can do so by using the `register(token: Data?)` method. If a user does not grant access to send notifications, you can also call this method without a token to register device characteristics.
```swift
Parcelvoy.shared.register(token: "APN_TOKEN_DATA")
```

#### Handle Notifications
When a notification is received it can contain a deeplink that will trigger when a user opens it. To properly handle the routing you need to pass the received push notification to the Parcelvoy handler.
```swift
func application(
    _ application: UIApplication,
    didReceiveRemoteNotification userInfo: [AnyHashable : Any]
) async -> UIBackgroundFetchResult {
    Parcelvoy.shared.handle(application, userInfo: userInfo)
    return .newData
}                     
```

### In-App Notifications
To allow for your app to receive custom UI in-app notifications you need to configure your app to properly parse and display them. This is handled by a custom delegate that you set when you initialize the SDK called `InAppDelegate`.
```swift

class CustomInAppDelegate: InAppDelegate {
    func handle(action: InAppAction, context: [String : AnyObject], notification: ParcelvoyNotification) {
        print("PV | Action: \(action) \(context)")
    }
}

Parcelvoy.initialize(
    apiKey: apiKey,
    urlEndpoint: urlEndpoint,
    inAppDelegate: CustomInAppDelegate(),
    launchOptions: launchOptions
)
```

This delegate contains three methods that you can configure to help you determine how and when notifications should display.
```swift
public protocol InAppDelegate: AnyObject {
    var autoShow: Bool { get }
    func onNew(notification: ParcelvoyNotification) -> InAppDisplayState
    func handle(action: InAppAction, context: [String: Any], notification: ParcelvoyNotification)
    func onError(error: Error)
}
```
- `autoShow: boolean`: Should notifications automatically display upon receipt and app open
- `onNew(notification: ParcelvoyNotification) -> InAppDisplayState`: When a notification is received (and `autoShow` is true), what should the SDK do? Options are:
    - `show`: Display the notification to the user
    - `skip`: Iterate to the next notification if there is one, otherwise do nothing. This does not mark the notification as read
    - `consume`: Mark the notification as read and never show again
- `handle(action: InAppAction, context: [String: Any], notification: ParcelvoyNotification)`: Triggered when an action is taken inside of a notification. Possible actions are:
    - `close`: Triggered to dismiss and consume a displayed notification
    - `custom`: Triggered with custom data for the app to utilize
- `onError(error: Error)`: Provide errors if any have been encountered

If you would like to manually handle showing notifications, this can be achieved by turning `autoShow` to false and then calling `Parcelvoy.shared.showLatestNotification()`

#### Helper Methods
- `getNofications() async throws -> Page<ParcelvoyNotification>`: Returns a page of notifications
- `showLatestNotification() async`: Display the latest notification to the user
- `show(notification: ParcelvoyNotification) async`: Display a provided notification to the user
- `consume(notification: ParcelvoyNotification) async`: Mark a notification as being read
- `dismiss(notification: ParcelvoyNotification) async`: Dismiss a notification if it is being displayed and mark it as being read

#### Handling In-App Actions
The SDK handles actions in a couple of different ways. At its simplest, to close a notification you can use the `parcelvoy://dismiss` deeplink.

If you'd like to pass information from the in-app notification to the app (for example based on what button they click, etc) you can use the JS trigger `window.custom(obj)` or use any other deeplink using the `parcelvoy://` scheme such as `parcelvoy://special/custom`

### Deeplink & Universal Link Navigation
To allow for click tracking links in emails can be click-wrapped in a Parcelvoy url that then needs to be unwrapped for navigation purposes. For information on setting this up on your platform, please see our [deeplink documentation](https://docs.parcelvoy.com/advanced/deeplinking).

Parcelvoy includes a method which checks to see if a given URL is a Parcelvoy URL and if so, unwraps the url, triggers the unwrapped URL and calls the Parcelvoy API to register that the URL was executed.

To start using deeplinking in your app, add your Parcelvoy deployment URL as an Associated Domain to your app. To do so, navigate to Project -> Target -> Select your primary target -> Signing & Capabilities. From there, scroll down to Associated Domains and hit the plus button. Enter the domain in the format `applinks:YOURDOMAIN.com` i.e. `applinks:parcelvoy.com`.

Next, you'll need to update your apps code to support unwrapping the Parcelvoy URLs that open your app. To do so, use the `handle(universalLink: URL)` method. In your app delegate's `application(_:continue:restorationHandler:)` method, unwrap the URL and pass it to the handler:

```swift
func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {

    guard let url = userActivity.webpageURL else {
        return false
    }

    return Parcelvoy.shared.handle(universalLink: url)
}
```

Parcelvoy links will now be automatically read and opened in your application.

## Example

Explore our [example project](/Example) which includes basic usage.
