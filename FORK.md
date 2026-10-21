# huuuiii fork plan

Reviewed on 2026-10-19 at upstream commit `693c951`.
This review records inherited behavior and the implementation backlog.
The fork is now named `huuuiii`; the original project is [Tabula](https://github.com/keyruu/Tabula).
The project, targets, source paths, resources, and app identity have been renamed, and the README identifies the fork.
GPL-3.0-or-later licensing has been added for the fork changes; inherited-code licensing still needs clarification.
Scrolling still uses the inherited pointer-to-pixel conversion, with updated binding recording and activation handling.
The app now uses Swift 6 language mode, a consistent macOS 14.0 minimum, shared unsandboxed entitlements, and LaunchAtLogin pinned to `1.1.0`.
Source line references below describe the inherited implementation and may shift as work is completed.

## What this repo does

huuuiii turns pointer movement into horizontal and vertical pixel scrolling while a selected modifier combination is held.
It runs as a menu bar application, stores preferences in `UserDefaults`, and uses LaunchAtLogin for its login setting.
The expected load is one local user, with pointer events arriving continuously during scrolling.

The application is seven Swift files:

| File | Responsibility |
| --- | --- |
| [AppDelegate.swift](huuuiii/AppDelegate.swift) | Startup, modifier matching, activation delay, pointer monitoring, and synthetic scroll events |
| [PermissionsService.swift](huuuiii/PermissionsService.swift) | Permission prompt and initial trust polling |
| [ContentView.swift](huuuiii/ContentView.swift) | Preferences and Quit |
| [HuuuiiiApp.swift](huuuiii/HuuuiiiApp.swift) | The only scene, a `MenuBarExtra` |
| [ModifierBinding.swift](huuuiii/ModifierBinding.swift) | Preference migration, modifier matching, recording state, and activation identifiers |
| [ModifierRecorder.swift](huuuiii/ModifierRecorder.swift) | The focused modifier recording field |
| [ScrollSettings.swift](huuuiii/ScrollSettings.swift) | Validated preferences and bounded scroll-event construction |

Lightweight logic and native recorder checks live in [tests](tests) and run with `just test`.
There are no CI workflows in the checkout.
The Xcode project contains empty unit-test and UI-test targets.

## Must fix

### 1. Resolved: a previous key press cannot activate a later session

**Where:** [AppDelegate.swift](huuuiii/AppDelegate.swift), lines 28–46 and 59–95.

**Inherited problem:** Delayed callbacks shared `stillPressed`, so releasing and pressing again made an old callback valid again.
With a 500 ms delay, press at 0 ms, release at 100 ms, and press at 200 ms: the old callback starts scrolling at 500 ms, only 300 ms into the new press.
The new callback then installs another mouse monitor at 700 ms without removing the first, and the overwritten monitor handle cannot be used to stop it.

**Changed:** Every activation has an identifier, and ending a session invalidates its pending callbacks before another session can start.
Releasing the combination, opening preferences, starting recording, or terminating the app cancels scrolling and removes the current mouse monitor.

**Checked:** Deterministic request, release, repress, and cancellation checks cover stale activation identifiers.
Actual global pointer-event behavior still needs a live check.

### 2. Resolved: first movement and reversals reach scroll output

**Where:** [AppDelegate.swift](huuuiii/AppDelegate.swift), lines 24–26 and 58–103.

**Changed:** Scrolling uses each delivered event's movement deltas instead of subtracting sampled cursor positions.
The first event is converted immediately, and the reversal heuristic and previous-position state have been removed.
Unrelated modifier flags no longer restart a matching session.

**Checked:** Scroll-output tests cover the first event, immediate reversals, repeated conversions, and unchanged cursor positions at several simulated display coordinates.
Cursor restoration remains tied to a session that received movement.
Live device and direction calibration remains pending.

### 3. Resolved: Debug and Release now share an unsandboxed policy

**Where:** [huuuiii.entitlements](huuuiii/huuuiii.entitlements) and `CODE_SIGN_ENTITLEMENTS` in [project.pbxproj](huuuiii.xcodeproj/project.pbxproj).

**Inherited problem:** Debug disabled App Sandbox and Release enabled it, despite both using the same global input and accessibility code.
Apple lists assistive accessibility API use among the activities incompatible with App Sandbox, so a working Debug build does not establish that the shipping application works.
See [Apple's sandbox restrictions](https://developer.apple.com/documentation/security/protecting-user-data-with-app-sandbox).

**Changed:** Both configurations use the same empty entitlement file, and the separate Release entitlement file and unused user-selected-file access have been removed.
Hardened Runtime remains enabled in project settings and is present in the locally signed Release artifact.
Xcode disables it for the normal locally signed Debug build.

**Check:** Verify global modifier observation and scroll posting in another application using the actual Release app.

### 4. Resolved: entering preferences cancels scrolling

**Where:** [AppDelegate.swift](huuuiii/AppDelegate.swift), lines 28 and 59.

**Inherited problem:** Both monitors are global monitors, which do not receive events delivered to huuuiii itself.
Starting a session in another application and releasing the modifier while huuuiii receives events can therefore miss the stop transition.
Apple documents this exclusion in [the global monitor API](https://developer.apple.com/documentation/appkit/nsevent/addglobalmonitorforevents(matching:handler:)).

**Changed:** Opening preferences, starting the recorder, and activating the app explicitly cancel pending and active scrolling.
Recording uses a separate local event monitor that is removed when the field loses focus or disappears.
All scroll monitors are removed on shutdown.
Keep a single event tap as a later option if pointer suppression becomes necessary.

**Check:** Start scrolling outside huuuiii, open its preferences, release the modifier, and return to another app.

## Should fix

### 5. Permission status stops updating after the first grant

**Where:** [PermissionsService.swift](huuuiii/PermissionsService.swift), lines 18–28, and [ContentView.swift](huuuiii/ContentView.swift), lines 18–24.

**Problem:** Polling stops as soon as trust is granted, and `needsPermission` is persisted as though it were a user preference.
The first display can show a stale value, and the code has no recovery path for a later permission change while the process remains alive.

**Do:** Read actual permission state on startup and when returning from System Settings, and derive the UI from that state.
Stop pending activation and monitoring when permission is unavailable, and restart at most once when it returns.
Provide an explanation and a button to open the appropriate System Settings pane.

**If skipped:** The UI can claim the app is ready while input observation or posting is unavailable.

**Check:** Cover denied startup, grant after startup, revocation, and regrant, including any relaunch macOS requires.

### 6. Validate movement deltas and anchored scroll targeting on hardware

**Where:** [AppDelegate.swift](huuuiii/AppDelegate.swift), lines 58–62 and 88–100.

**Inherited problem:** The code sampled absolute cursor positions instead of using movement deltas from the delivered event.
Once the cursor reaches a display edge, further movement in that direction cannot produce further position changes for this algorithm.
The cursor also moves over other controls during scrolling, and the generated scroll event does not explicitly target the original position.

**Changed:** Conversion now reads the delivered movement deltas even when cursor coordinates are unchanged.
Generated scroll events explicitly use the session's starting location.
Failure to read the initial cursor location cancels activation instead of force-unwrapping it.

**Remaining:** Validate edge behavior and routing on real devices and applications.
The pointer still physically moves during scrolling; prototype an event tap that consumes active pointer movement if hover changes or routing require it.
An event tap needs explicit failure handling, cleanup, and recovery when macOS disables it.

**If skipped:** Long scrolls can stop at screen edges, and moving across panes can change the scroll target.

**Check:** Test every screen edge, multiple displays, nested scroll views, and both pointer and trackpad input before choosing the implementation.

### 7. Validated preferences no longer crash the event path

**Where:** [AppDelegate.swift](huuuiii/AppDelegate.swift), lines 39–60, 73–85, and 113–115.

**Inherited problem:** Preferences used forced casts, and scaled movement was converted directly to `Int32`.
A wrongly typed preference or a non-finite or oversized speed written through `defaults` can crash the app rather than fall back to a valid value.

**Changed:** Strict numeric and Boolean reads fall back for invalid types, reject non-finite settings, and clamp speed and delay to the UI ranges.
Startup and opening preferences normalize stored values before the controls use them.
Scroll deltas reject non-finite input and saturate before integer conversion, including multiplication overflow and natural-scroll reversal.

**Remaining:** Handle failure to create a cursor event or register a monitor without force-unwrapping or silently claiming readiness.

**If skipped:** Invalid stored settings can repeatedly crash the app when scrolling starts.

**Checked:** `ScrollSettingsTests` covers missing, wrongly typed, negative, non-finite, and oversized numeric preferences, Boolean validation, normalization, both axes, and bounded conversion.
Failed monitor installation remains to be covered with permission recovery.

### 8. Finish dependency and release setup after establishing fork identity

**Where:** [project.pbxproj](huuuiii.xcodeproj/project.pbxproj), [Package.resolved](huuuiii.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved), and [README.md](README.md).

**Completed:** The project and app are named `huuuiii`, use `io.github.atamanroman.huuuiii`, and no longer select upstream's development team.
Debug uses local ad hoc signing and builds without a development team.
Diagnosing a missing Debug permission on macOS 27 confirmed that TCC rejected the current build because the saved Accessibility grant required an older code hash.
The README documents resetting only the fork's grant and approving the current build again.
Debug and `just release` both need a consistent certificate to preserve grants across changed builds.
LaunchAtLogin is pinned to exactly `1.1.0` in the project and lockfile, preserving the previously locked source revision.
The README identifies the Tabula fork, credits the original authors, and explains that upstream downloads install Tabula.
Existing Tabula preferences are intentionally not migrated automatically, and permission grants and login registration belong to the new app identity.

**Remaining problem:** Release signing still needs the maintainer's own team and credentials.

**Do:** Configure the maintainer's signing team before testing permission persistence and login registration.
Point installation instructions at the fork once artifacts exist.
GPL-3.0-or-later now covers the fork changes, and the full GPL v3 text is in [LICENSE](LICENSE).
Keep upstream attribution and clarify the missing inherited-code license and borrowed-code provenance before distributing releases.

**If skipped:** Releases lack verified distribution signing and inherited-code licensing.

**Check:** Install the fork alongside upstream, verify separate preferences and login items, and test an upgrade of the signed fork.

## Requested changes

### 9. Support the current macOS release

- [ ] Build with the current stable Xcode and macOS SDK, then verify Debug and signed Release on macOS 27.
- [x] Retain macOS 14.0 as the minimum supported version while building with the selected Xcode SDK.
- [x] Align deployment targets across project, app, and retained test targets at macOS 14.0.
- [x] Migrate all application and retained test targets to Swift 6 language mode.
- [ ] Refresh the README and screenshots after behavior and permission wording are settled.

Apple lists macOS 27.0.1 as the latest release on the review date, matching this machine's `sw_vers` output.
See [Apple's release list](https://support.apple.com/en-us/100100).
The project was created with Xcode 15.4 and now uses Swift 6 language mode with macOS 14.0 deployment targets.
The app delegate, permission service, and permission-grant callback are isolated to the main actor, and the service singleton is immutable.
Only the SDK's mutable declaration of the permission prompt key uses a scoped `@preconcurrency` import; that key is read without taking ownership.
LaunchAtLogin retains its own declared language mode rather than being forced into the app's Swift 6 mode.
`SDKROOT = macosx` already selects the SDK from the chosen Xcode; setting the deployment target to 27 would drop older systems rather than select a newer SDK.

### 10. Allow modifier combinations and hide the activation modifiers

The activation modifiers must be hidden from applications and macOS while huuuiii generates scrolling.
Ctrl+scroll can trigger zoom, so modifier suppression is required behavior rather than an optional compatibility check.

- [x] Replace the picker with a field that records Control, Option, Command, Shift, and Function combinations.
- [x] Save after all modifiers are released, with Escape and focus loss cancelling recording.
- [x] Store the selection as a modifier bit mask and migrate the existing `modifier` string.
- [x] Preserve the existing Option default and prevent an empty selection from enabling scrolling unconditionally.
- [x] Match the complete selected combination against the supported modifier flags, ignoring unrelated flags such as Caps Lock.
- [x] Preserve exact-match behavior: an extra supported modifier stops scrolling.
- [x] Reuse session cancellation whenever matching changes or recording begins.
- [ ] Test every single modifier, multiple press/release orders, extra modifiers, Caps Lock, and Function/Globe behavior on real hardware.
- [ ] Strip the selected activation modifiers from generated scroll events.
- [ ] Verify whether clearing event flags also prevents actions driven by the physically held modifier; if necessary, prototype event interception that hides activation modifiers for the active scrolling session.
- [ ] Preserve ordinary modifier shortcuts outside scrolling, including presses released before the trigger delay, and restore consistent modifier state after release or cancellation.
- [ ] With macOS modifier-scroll zoom enabled, verify that Control-triggered huuuiii scrolling scrolls without zooming.
- [ ] Verify that combinations containing Control, Command, Option, or Shift do not trigger zoom, navigation, or other modified-scroll actions in target apps.

**Implemented in:** `ModifierBinding.swift`, `ModifierRecorder.swift`, `ContentView.swift`, `AppDelegate.swift`, and the checks in `tests`.
Modifier suppression and an updated screenshot remain separate work.
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

- [ ] Add “Hide Menu Bar Icon” with adjacent guidance that opening huuuiii again restores access.
- [ ] Restore access when the already running app is opened from Finder, Spotlight, or the command line.
- [ ] Keep scrolling alive while hidden and keep a reachable route to preferences and Quit after reopening.
- [ ] Start with session-only hiding, matching SensibleSideButtons; add persistence only if wanted later.
- [ ] Verify permission recovery remains visible or recoverable while the icon is hidden.

**Touches:** `HuuuiiiApp.swift`, `AppDelegate.swift`, `ContentView.swift`, and lifecycle checks.
[SensibleSideButtons' implementation](https://github.com/archagon/sensible-side-buttons/blob/master/SensibleSideButtons/AppDelegate.m) hides an `NSStatusItem` through `setVisible:NO` and restores it in `applicationShouldHandleReopen`.
SwiftUI offers an [`isInserted` binding](https://developer.apple.com/documentation/swiftui/menubarextra/init(isinserted:content:label:)), but Apple documents automatic termination when a menu-only app's extra is removed in [the MenuBarExtra lifecycle](https://developer.apple.com/documentation/swiftui/menubarextra).
Prototype that lifecycle before settling on SwiftUI visibility; use an AppKit-owned `NSStatusItem` hosting the existing SwiftUI preferences if necessary to preserve background operation.

### 13. Investigate trackpad-style scrolling before replacing events

The original request says “touchbar events”; whether that means trackpad gestures or the MacBook Touch Bar remains open.
Treat this as an experiment until the desired effect is clear.

huuuiii already posts pixel-based `CGEvent` scroll-wheel events.
Trackpad scrolling is also exposed to applications as scrolling, with continuous deltas and gesture or momentum phases; a different event category is not automatically required for smoother output.
Apple exposes [`scrollWheelEventIsContinuous`](https://developer.apple.com/documentation/coregraphics/cgeventfield/scrollwheeleventiscontinuous), [`scrollWheelEventScrollPhase`](https://developer.apple.com/documentation/coregraphics/cgeventfield/scrollwheeleventscrollphase), and [`scrollWheelEventMomentumPhase`](https://developer.apple.com/documentation/coregraphics/cgeventfield/scrollwheeleventmomentumphase).
Those fields provide an investigation path, not proof that setting them reproduces native trackpad behavior in every app.
The [Touch Bar API](https://developer.apple.com/documentation/appkit/nstouchbar) serves a separate hardware interface.

- [ ] Identify the desired effect: smoother deltas, inertia, gesture recognition, or actual Touch Bar input.
- [x] Convert delivered movement deltas without dropping the first movement or reversals; hardware edge checks remain pending.
- [ ] Compare the current pixel output with a minimal phase-aware prototype in Safari, Finder, a native scroll view, and an Electron app.
- [ ] Check diagonal scrolling, immediate reversal, release, cancellation, app switching, and held-modifier behavior.
- [ ] Implement momentum only if requested, including immediate cancellation on new input.
- [ ] Avoid private gesture-event synthesis unless a concrete requirement cannot be met with public scrolling APIs.

**Touches if adopted:** Scroll generation and session lifecycle in `AppDelegate.swift`, event-sequence tests, and hardware checks.
Keep the current event mechanism until the experiment demonstrates a specific improvement.

### 14. Filter by pointing device

Allow selecting which mice, trackpads, or other pointing devices huuuiii converts into scrolling.
For example, holding the activation combination should convert movement from a selected trackpad while an excluded mouse continues to move the pointer normally.
The current implementation reads mouse-event deltas but does not identify their physical source, so it cannot distinguish those inputs.

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
2. Finish movement-state and preference validation fixes, with focused tests.
3. Prototype device attribution together with activation-modifier suppression, then add device selection and permission recovery.
4. Add icon hiding with reliable reopen behavior.
5. Investigate scrolling deltas and gesture phases against a repeatable hardware baseline.
6. Update screenshots and installation instructions, then sign, notarize, and verify the actual distributed app.

Extend the lightweight checks in `tests` for matching, migration, delayed activation, and movement calculations.
Avoid a broad UI-test suite; permission dialogs, login behavior, pointer routing, and menu bar lifecycle still need real macOS checks.
Verify delay extremes, speed extremes, both axes individually and together, natural scrolling, sleep/wake, multiple displays, selected and excluded devices, and rapid modifier changes.

## Verification and limits of this review

- Read all seven Swift sources, the original entitlement files, the Xcode project, the dependency lockfile, and the README.
- Confirmed the project and entitlement property lists pass `plutil -lint`.
- Reproduced the delayed-activation race and cross-session reversal suppression in small deterministic models without installing input monitors.
- Confirmed local macOS 27.0.1 and Xcode 27.1, and checked Apple's release and API documentation plus SensibleSideButtons' source.
- Repaired the initial Xcode framework mismatch with `xcodebuild -runFirstLaunch`, installing Xcode 27.1 system resources in place of the older 26.3 resources.
- Reproduced the Swift 6 singleton isolation error before migrating permission handling to the main actor.
- Type-checked the scoped permission-key import in Swift 6 with warnings treated as errors.
- Built Debug and Release in Swift 6 on macOS 27.0.1 using Xcode 27.1, with the lockfile restricted to LaunchAtLogin `1.1.0`.
- Verified both local ad hoc signatures and inspected both built apps for the absence of sandbox and file-access entitlements and a macOS 14.0 minimum.
- Release used an explicit local signing override for verification; distribution signing, notarization, and runtime testing remain pending.
- Ran `just test` for legacy preference migration, exact modifier matching, recording order, and stale activation cancellation.
- Exercised the native field with local events, including rapid release, typed letters, Escape, focus loss, and removal without changing the saved chord.
- No macOS 14 runtime or physical keyboard verification was performed.
- Launched Debug while diagnosing the stale Accessibility grant, reset only the fork's grant, and reopened the same build for approval.
- Did not verify access after approval, change login items, run signed Release behavior, inspect every binary image, or test physical pointer and trackpad hardware.

**Verdict:** Finish movement handling and modifier suppression, then verify global scrolling and permission behavior using the signed Release app.
Skip new dependencies, a broad architecture rewrite, automatic updating, and private gesture synthesis for this first fork pass.
