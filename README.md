# Open Progress

A native SwiftUI countdown/progress app with WidgetKit widgets for personal use.

## What is included

- iOS SwiftUI app for creating and editing countdowns.
- Shared JSON storage for app and widget data.
- WidgetKit extension with Home Screen sizes and Lock Screen accessory families.
- Five original widget styles: Swiss, Grid, Aqua, Retro, and Minimal.

## Run it

Generate the Xcode project, then open it:

```sh
xcodegen generate
open OpenProgress.xcodeproj
```

Select the `OpenProgress` scheme and run on a simulator or device.

For a physical iPhone, change these values to match your Apple developer account:

- App bundle ID: `com.openprogress.personal`
- Widget bundle ID: `com.openprogress.personal.widgets`
- App Group: `group.com.openprogress.personal`

The app and widget both need the same App Group enabled so edited countdowns appear in widgets.
