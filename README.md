# huuuiii

<img alt="huuuiii icon inherited from Tabula" src="images/huuuiii-512.png" width="150px"/>

huuuiii is a fork of [keyruu/Tabula](https://github.com/keyruu/Tabula), originally created by Lucas Rott.
It enables one-finger scrolling on macOS by converting pointer movement into scrolling while a modifier key is held.
The fork starts from Tabula 1.5.0 and retains its scrolling behavior while the changes in [FORK.md](FORK.md) are developed.

## Current features

- Hold a configurable modifier to scroll horizontally and vertically.
- Adjust scroll speed, activation delay, and scrolling direction.
- Enable launch at login.

The inherited settings interface is shown below.

<img alt="Settings inherited from Tabula" src="images/huuuiii-settings.png" width="300px"/>

Modifier combinations, modifier suppression, device filtering, updated permission guidance, and menu bar icon hiding are planned in [FORK.md](FORK.md).

## Build

Open `huuuiii.xcodeproj` in Xcode, select the `huuuiii` scheme, and choose your own signing team before building.
The app uses the bundle identifier `io.github.atamanroman.huuuiii` and keeps its preferences and login registration separate from Tabula.
Existing Tabula preferences are not migrated automatically, and macOS permissions must be granted to the fork separately.
Upstream releases and the `keyruu-tabula` Homebrew package install Tabula rather than huuuiii.

## Credits and license

Thanks to Lucas Rott for [Tabula](https://github.com/keyruu/Tabula), [arifiorino/Scroller](https://github.com/arifiorino/Scroller) for the base scrolling algorithm, and [othyn/macos-auto-clicker](https://github.com/othyn/macos-auto-clicker) for the permission-service reference.
The original author stated that Tabula is no longer maintained and explicitly invited forks.
Original author notices and inherited artwork are retained.

Changes made for huuuiii are licensed under the GNU General Public License, version 3 or, at your option, any later version (`GPL-3.0-or-later`).
See [LICENSE](LICENSE) for the full license text.
The inherited Tabula checkout did not contain a license file; adding this license does not establish permission to relicense inherited code or artwork.
Clarifying those upstream terms remains a release prerequisite in [FORK.md](FORK.md).
