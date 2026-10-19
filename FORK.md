# Tabula fork plan

Reviewed on 2026-10-19 at upstream commit `693c951`.
This is a review and implementation backlog; the application has not been changed.

## What this repo does

Tabula turns pointer movement into horizontal and vertical pixel scrolling while a selected modifier is held.
It runs as a menu bar application, stores preferences in `UserDefaults`, and uses LaunchAtLogin for its login setting.
The expected load is one local user, with pointer events arriving continuously during scrolling.

The complete application is four Swift files:

| File | Responsibility |
| --- | --- |
| [AppDelegate.swift](Tabula/AppDelegate.swift) | Startup, modifier matching, activation delay, pointer monitoring, and synthetic scroll events |
| [PermissionsService.swift](Tabula/PermissionsService.swift) | Permission prompt and initial trust polling |
| [ContentView.swift](Tabula/ContentView.swift) | Preferences and Quit |
| [TabulaApp.swift](Tabula/TabulaApp.swift) | The only scene, a `MenuBarExtra` |

There are no test sources or CI workflows in the checkout.
The Xcode project contains empty unit-test and UI-test targets.

## Must fix

### 1. A previous key press can activate scrolling during a later press

**Where:** [AppDelegate.swift](Tabula/AppDelegate.swift), lines 28–46 and 59–95.

**Problem:** Delayed callbacks share `stillPressed`, so releasing and pressing again makes an old callback valid again.
With a 500 ms delay, press at 0 ms, release at 100 ms, and press at 200 ms: the old callback starts scrolling at 500 ms, only 300 ms into the new press.
The new callback then installs another mouse monitor at 700 ms without removing the first, and the overwritten monitor handle cannot be used to stop it.

**Do:** Own one pending activation and one mouse monitor on `AppDelegate`.
Invalidate the pending activation whenever the modifier combination stops matching, and check an activation identifier before installing a monitor.
Make starting and stopping safe to call repeatedly, including permission recovery and termination.

**If skipped:** Rapid modifier use can produce duplicate scrolling and scrolling that continues after release.

**Check:** Add a deterministic test for press, release, and repress before the delay expires, asserting one activation after the full second delay and no active monitors after release.

### 2. Pointer state survives sessions and drops valid movement

**Where:** [AppDelegate.swift](Tabula/AppDelegate.swift), lines 24–26 and 58–103.

**Problem:** `lastDelta` is never cleared, so the next scrolling session can discard a movement that happens to reverse the previous session's last movement.
The same reversal check also discards intentional direction changes within a session.
`lastPos` starts empty, so the first movement is discarded, and a matching flags change can overwrite the starting position without clearing the previous position.

**Do:** Initialize and reset all movement state at explicit session boundaries.
Remove the reversal heuristic unless a reproducible synthetic-event feedback case justifies it; if feedback exists, identify generated events instead of guessing from direction.
Keep cursor restoration tied to the session that actually started.

**If skipped:** Short movements and direction reversals can feel unresponsive, and cursor restoration can use the wrong origin.

**Check:** Cover first movement, immediate reversal, two consecutive sessions, and unrelated modifier-flag changes.

### 3. Debug and Release use different sandbox policies

**Where:** [Tabula.entitlements](Tabula/Tabula.entitlements), [TabulaRelease.entitlements](Tabula/TabulaRelease.entitlements), and `CODE_SIGN_ENTITLEMENTS` in [project.pbxproj](Tabula.xcodeproj/project.pbxproj).

**Problem:** Debug disables App Sandbox and Release enables it, despite both using the same global input and accessibility code.
Apple lists assistive accessibility API use among the activities incompatible with App Sandbox, so a working Debug build does not establish that the shipping application works.
See [Apple's sandbox restrictions](https://developer.apple.com/documentation/security/protecting-user-data-with-app-sandbox).

**Do:** Use the same unsandboxed policy for Debug and direct-distribution Release builds, and retain Hardened Runtime for signing and notarization.
Remove the user-selected-file entitlement if the app continues to have no file-access feature.
Inspect the built app's entitlements and test the signed Release artifact with fresh permission grants.

**If skipped:** The distributed build can fail even when a local development build works.

**Check:** Verify global modifier observation and scroll posting in another application using the actual Release app.

### 4. Releasing the modifier inside Tabula can leave scrolling active

**Where:** [AppDelegate.swift](Tabula/AppDelegate.swift), lines 28 and 59.

**Problem:** Both monitors are global monitors, which do not receive events delivered to Tabula itself.
Starting a session in another application and releasing the modifier while Tabula receives events can therefore miss the stop transition.
Apple documents this exclusion in [the global monitor API](https://developer.apple.com/documentation/appkit/nsevent/addglobalmonitorforevents(matching:handler:)).

**Do:** Route local and global modifier changes through the same session transition logic, and stop an active session when the app becomes active.
Remove every registered monitor on shutdown.
Keep a single event tap as a later option if pointer suppression becomes necessary.

**If skipped:** Opening preferences while scrolling can leave the internal modifier state out of sync with the keyboard.

**Check:** Start scrolling outside Tabula, open its preferences, release the modifier, and return to another app.

## Should fix

### 5. Permission status stops updating after the first grant

**Where:** [PermissionsService.swift](Tabula/PermissionsService.swift), lines 18–28, and [ContentView.swift](Tabula/ContentView.swift), lines 18–24.

**Problem:** Polling stops as soon as trust is granted, and `needsPermission` is persisted as though it were a user preference.
The first display can show a stale value, and the code has no recovery path for a later permission change while the process remains alive.

**Do:** Read actual permission state on startup and when returning from System Settings, and derive the UI from that state.
Stop pending activation and monitoring when permission is unavailable, and restart at most once when it returns.
Provide an explanation and a button to open the appropriate System Settings pane.

**If skipped:** The UI can claim the app is ready while input observation or posting is unavailable.

**Check:** Cover denied startup, grant after startup, revocation, and regrant, including any relaunch macOS requires.

### 6. Scrolling depends on the pointer's bounded screen position

**Where:** [AppDelegate.swift](Tabula/AppDelegate.swift), lines 58–62 and 88–100.

**Problem:** The code samples absolute cursor positions instead of using movement deltas from the delivered event.
Once the cursor reaches a display edge, further movement in that direction cannot produce further position changes for this algorithm.
The cursor also moves over other controls during scrolling, and the generated scroll event does not explicitly target the original position.

**Do:** Test event movement deltas as the smallest fix for scrolling at screen edges.
Decide whether scrolling should remain anchored to its starting location; if so, prototype an event tap that consumes active pointer movement and keeps the cursor anchored.
An event tap needs explicit failure handling, cleanup, and recovery when macOS disables it.

**If skipped:** Long scrolls can stop at screen edges, and moving across panes can change the scroll target.

**Check:** Test every screen edge, multiple displays, nested scroll views, and both pointer and trackpad input before choosing the implementation.

### 7. Stored values can crash the event path

**Where:** [AppDelegate.swift](Tabula/AppDelegate.swift), lines 39–60, 73–85, and 113–115.

**Problem:** Preferences use forced casts, and scaled movement is converted directly to `Int32`.
A wrongly typed preference or a non-finite or oversized speed written through `defaults` can crash the app rather than fall back to a valid value.

**Do:** Use typed preference reads with defaults, validate finite speed and delay against the UI ranges, and bound values before integer conversion.
Handle failure to create an event or register a monitor without force-unwrapping or silently claiming readiness.

**If skipped:** Invalid stored settings can repeatedly crash the app when scrolling starts.

**Check:** Test missing, wrongly typed, negative, non-finite, and oversized numeric preferences, plus a failed monitor installation.

### 8. The fork still builds and advertises itself as upstream

**Where:** [project.pbxproj](Tabula.xcodeproj/project.pbxproj), [Package.resolved](Tabula.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved), and [README.md](README.md).

**Problem:** The app uses upstream's `de.keyruu.Tabula` identifier and development team, while downloads and Homebrew instructions still install upstream.
LaunchAtLogin tracks `main`, with a revision recorded in the lockfile, so an intentional dependency refresh can move to unreviewed branch content.

**Do:** Choose the fork's bundle identifier and signing configuration before testing permissions and login registration, since changing identity later affects both.
Explain how existing preferences are migrated or intentionally reset.
Pin a reviewed LaunchAtLogin release, update the lockfile, and point installation instructions at the fork once artifacts exist.
Keep upstream attribution and record the README's explicit invitation to fork; clarify the missing repository license and borrowed-code provenance before distributing releases under a chosen license.

**If skipped:** Users can install the wrong app, builds depend on upstream configuration, and identity changes complicate upgrades and permission grants.

**Check:** Install the fork alongside upstream, verify separate preferences and login items, and test an upgrade of the signed fork.

## Requested changes

### 9. Support the current macOS release

- [ ] Build with the current stable Xcode and macOS SDK, then verify Debug and signed Release on macOS 27.
- [ ] Decide the oldest supported macOS separately from the SDK used to build.
- [ ] Align deployment targets across project, app, and retained test targets.
- [ ] Review compiler warnings before deciding whether a Swift language-mode migration is needed.
- [ ] Refresh the README and screenshots after behavior and permission wording are settled.

Apple lists macOS 27.0.1 as the latest release on the review date, matching this machine's `sw_vers` output.
See [Apple's release list](https://support.apple.com/en-us/100100).
The project was created with Xcode 15.4, uses Swift 5 language mode, and sets macOS 14.5 at project level but 14.0 on the app target.
`SDKROOT = macosx` already selects the SDK from the chosen Xcode; setting the deployment target to 27 would drop older systems rather than select a newer SDK.

### 10. Allow modifier combinations and hide the activation modifiers

The activation modifiers must be hidden from applications and macOS while Tabula generates scrolling.
Ctrl+scroll can trigger zoom, so modifier suppression is required behavior rather than an optional compatibility check.

- [ ] Replace the single-value picker with independent selections for Control, Option, Command, Shift, and Function.
- [ ] Store the selection as a modifier bit mask and migrate the existing `modifier` string once.
- [ ] Preserve the existing Option default and prevent an empty selection from enabling scrolling unconditionally.
- [ ] Match the complete selected combination against the supported modifier flags, ignoring unrelated flags such as Caps Lock.
- [ ] Preserve today's exact-match behavior: an extra supported modifier stops scrolling.
- [ ] Reuse the session cancellation from item 1 whenever matching changes or the preference is edited.
- [ ] Test every single modifier, multiple press/release orders, extra modifiers, Caps Lock, and Function/Globe behavior on real hardware.
- [ ] Strip the selected activation modifiers from generated scroll events.
- [ ] Verify whether clearing event flags also prevents actions driven by the physically held modifier; if necessary, prototype event interception that hides activation modifiers for the active scrolling session.
- [ ] Preserve ordinary modifier shortcuts outside scrolling, including presses released before the trigger delay, and restore consistent modifier state after release or cancellation.
- [ ] With macOS modifier-scroll zoom enabled, verify that Control-triggered Tabula scrolling scrolls without zooming.
- [ ] Verify that combinations containing Control, Command, Option, or Shift do not trigger zoom, navigation, or other modified-scroll actions in target apps.

**Touches:** `ContentView.swift`, modifier observation and scroll generation in `AppDelegate.swift`, preference migration, focused unit tests, and the README screenshot.
`NSEvent.ModifierFlags` already represents combinations, so this needs no shortcut-recording dependency or general hotkey framework.

### 11. Use “Device Control and Data Access” in permission guidance

- [ ] Replace the misspelled `accessbility` message with the current settings name and a short explanation of why input access is needed.
- [ ] If older macOS versions remain supported, show their “Accessibility” label on those systems.
- [ ] Keep the documented `AXIsProcessTrusted` and `AXIsProcessTrustedWithOptions` checks unless testing establishes a different requirement.
- [ ] Verify the System Settings link on every supported major version.
- [ ] Request only the permissions the chosen observation and posting implementation actually needs.

**Touches:** `PermissionsService.swift`, `ContentView.swift`, permission recovery in `AppDelegate.swift`, screenshots, and setup instructions.
The installed macOS 27.0.1 System Settings resource `SecurityPrivacyExtension.appex/Contents/Resources/Localizable.loctable` maps the English `ACCESSIBILITY` key to “Device Control and Data Access”.
This confirms the UI label locally; Apple's public API remains documented under [AXIsProcessTrustedWithOptions](https://developer.apple.com/documentation/applicationservices/1459186-axisprocesstrustedwithoptions).
The label change alone does not establish that the permission API or required grants changed.

### 12. Hide and restore the menu bar icon

- [ ] Add “Hide Menu Bar Icon” with adjacent guidance that opening Tabula again restores access.
- [ ] Restore access when the already running app is opened from Finder, Spotlight, or the command line.
- [ ] Keep scrolling alive while hidden and keep a reachable route to preferences and Quit after reopening.
- [ ] Start with session-only hiding, matching SensibleSideButtons; add persistence only if wanted later.
- [ ] Verify permission recovery remains visible or recoverable while the icon is hidden.

**Touches:** `TabulaApp.swift`, `AppDelegate.swift`, `ContentView.swift`, and lifecycle checks.
[SensibleSideButtons' implementation](https://github.com/archagon/sensible-side-buttons/blob/master/SensibleSideButtons/AppDelegate.m) hides an `NSStatusItem` through `setVisible:NO` and restores it in `applicationShouldHandleReopen`.
SwiftUI offers an [`isInserted` binding](https://developer.apple.com/documentation/swiftui/menubarextra/init(isinserted:content:label:)), but Apple documents automatic termination when a menu-only app's extra is removed in [the MenuBarExtra lifecycle](https://developer.apple.com/documentation/swiftui/menubarextra).
Prototype that lifecycle before settling on SwiftUI visibility; use an AppKit-owned `NSStatusItem` hosting the existing SwiftUI preferences if necessary to preserve background operation.

### 13. Investigate trackpad-style scrolling before replacing events

The original request says “touchbar events”; whether that means trackpad gestures or the MacBook Touch Bar remains open.
Treat this as an experiment until the desired effect is clear.

Tabula already posts pixel-based `CGEvent` scroll-wheel events.
Trackpad scrolling is also exposed to applications as scrolling, with continuous deltas and gesture or momentum phases; a different event category is not automatically required for smoother output.
Apple exposes [`scrollWheelEventIsContinuous`](https://developer.apple.com/documentation/coregraphics/cgeventfield/scrollwheeleventiscontinuous), [`scrollWheelEventScrollPhase`](https://developer.apple.com/documentation/coregraphics/cgeventfield/scrollwheeleventscrollphase), and [`scrollWheelEventMomentumPhase`](https://developer.apple.com/documentation/coregraphics/cgeventfield/scrollwheeleventmomentumphase).
Those fields provide an investigation path, not proof that setting them reproduces native trackpad behavior in every app.
The [Touch Bar API](https://developer.apple.com/documentation/appkit/nstouchbar) serves a separate hardware interface.

- [ ] Identify the desired effect: smoother deltas, inertia, gesture recognition, or actual Touch Bar input.
- [ ] Fix dropped movements and screen-edge behavior first so those defects do not distort the comparison.
- [ ] Compare the current pixel output with a minimal phase-aware prototype in Safari, Finder, a native scroll view, and an Electron app.
- [ ] Check diagonal scrolling, immediate reversal, release, cancellation, app switching, and held-modifier behavior.
- [ ] Implement momentum only if requested, including immediate cancellation on new input.
- [ ] Avoid private gesture-event synthesis unless a concrete requirement cannot be met with public scrolling APIs.

**Touches if adopted:** Scroll generation and session lifecycle in `AppDelegate.swift`, event-sequence tests, and hardware checks.
Keep the current event mechanism until the experiment demonstrates a specific improvement.

### 14. Filter by pointing device

Allow selecting which mice, trackpads, or other pointing devices Tabula converts into scrolling.
For example, holding the activation combination should convert movement from a selected trackpad while an excluded mouse continues to move the pointer normally.
The current implementation discards the mouse event and samples the shared cursor position, so it cannot distinguish those inputs.

- [ ] Offer “All pointing devices” for the existing behavior and a selection of individual connected devices.
- [ ] Identify the physical source of each movement before conversion, and prove reliable attribution with two devices connected before choosing the input API.
- [ ] Persist device selection using stable identity where available, and handle identical models without silently selecting both.
- [ ] Keep excluded devices' movement and native scrolling unchanged, and ensure their movement cannot affect a selected device's scroll delta or cursor restoration.
- [ ] Coordinate filtering with activation-modifier suppression so converting the selected device does not break ordinary input from excluded devices.
- [ ] Handle disconnect, reconnect, sleep/wake, and an unavailable selected device without falling back to converting every device.
- [ ] Test a selected trackpad and excluded mouse, two mice including identical models, simultaneous movement, reconnect, and movement whose source cannot be identified.

**Touches:** Device selection in `ContentView.swift`, input attribution and session state in `AppDelegate.swift`, preference storage, device lifecycle handling, focused tests, and the README.
Treat reliable device attribution and modifier suppression as one early input prototype; verify feasibility before extending the current global-monitor implementation.
Keep this scoped to pointing devices; separate activation-keyboard filtering is not required by this plan.

## Implementation order and release checks

1. Establish fork identity, consistent entitlements, and a working current-Xcode build.
2. Fix session cancellation, movement state, local modifier handling, and preference validation with focused tests.
3. Prototype device attribution together with activation-modifier suppression, then add device selection, modifier combinations, and permission recovery, including migration from existing settings.
4. Add icon hiding with reliable reopen behavior.
5. Investigate scrolling deltas and gesture phases against a repeatable hardware baseline.
6. Update screenshots and installation instructions, then sign, notarize, and verify the actual distributed app.

Use the existing unit-test target for matching, migration, delayed activation, and movement calculations.
Avoid a broad UI-test suite; permission dialogs, login behavior, pointer routing, and menu bar lifecycle still need real macOS checks.
Verify delay extremes, speed extremes, both axes individually and together, natural scrolling, sleep/wake, multiple displays, selected and excluded devices, and rapid modifier changes.

## Verification and limits of this review

- Read all four Swift sources, both entitlement files, the Xcode project, the dependency lockfile, and the README.
- Confirmed the project and entitlement property lists pass `plutil -lint`.
- Reproduced the delayed-activation race and cross-session reversal suppression in small deterministic models without installing input monitors.
- Confirmed local macOS 27.0.1 and Xcode 27.1, and checked Apple's release and API documentation plus SensibleSideButtons' source.
- Attempted `xcodebuild -list` with automatic package resolution disabled.
- Project inspection exited with code 70 before compilation because `IDESimulatorFoundation` could not resolve a symbol in `/Library/Developer/PrivateFrameworks/DVTDownloads.framework`.
- This is a local Xcode/framework mismatch; no application compilation result or passing test run is claimed.
- Did not launch Tabula, change privacy grants or login items, run signed Release behavior, inspect every binary image, or test physical pointer and trackpad hardware.

**Verdict:** Fix activation ownership and establish a Release build that can perform its core input work before adding the requested features.
Skip new dependencies, a broad architecture rewrite, automatic updating, and private gesture synthesis for this first fork pass.
