# TMGHTTPClockSync
TMGHTTPClockSync allows a device to sync it's clock with a server.

- [Requirements](#requirements)
- [Flow Diagram](https://github.com/MeetMe/TMGHTTPClockSync/blob/master/Syncing%20Mobile%20-%20Server%20clocks.pdf)
- [Usage](#usage)
- [Credits](#credits)
- [License](#license)

## Requirements

- iOS 9.0+, watchOS 5.1+, tvOS 12.1+, macOS 10.14+
- Xcode 10.1+
- Swift 4.2+

## Usage

### Setting up the controller

TMGHTTPClockSync should be configured on initialization.
This is done with a TMGClockSyncController.Config struct that starts with sane defaults

A basic config would at least set the `getServerTime` property

```swift
let config = TMGClockSyncController.Config { (completion) in
    SomeEndpoint.SendRequest { (serverTime) in
        completion(serverTime)
    }
}
```

Next, create a `TMGClockSyncController` with the config.
Then call `syncClocks()` and let the controller get to work.

```swift
let controller = TMGClockSyncController(config: config)
controller.syncClocks()
```
It probably makes sense to keep the controller alive as long as your session.
Perhaps using a static let.

### Using the controller

Each `TMGClockSyncController` will call to the server set in the configuration to get the delta between device and server time.
If no delta is set yet, one will be set the first time it makes a server call.
The controller will then get more data points up to `maxDataPoints` in the config.
A more accurate delta will then be calculated by eliminating outliers using standard deviation.

Every time the device/server delta is updated, the controller will send a notification using `clockSyncDidUpdateNotificationName`.

A public var will tell you what time the server has at any given moment.
```swift
public var serverTime: Date
```

## Credits

TMGHTTPClockSync is owned and maintained by the [The Meet Group](https://www.themeetgroup.com).

## License

TMGHTTPClockSync is released under the BSD license. [See LICENSE](https://github.com/MeetMe/TMGHTTPClockSync/blob/master/LICENSE.md) for details.
