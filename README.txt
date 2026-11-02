ATU4K Control 0.9.4 (24)

Standalone controller for the TrueLadderLine ATU4K with StepperTune-BT USB interface.
The macOS app supports Full, Compact and Mini layouts, Light/Dark appearance,
capacitor and inductor readouts, two banks of eight named presets, confirmed
recall, explicit overwrite/save, and one-step or 100-step jog controls.
This is independent development software, not an official manufacturer release.

Build on an Apple Silicon Mac with Xcode command-line tools:
    sh build-mac.sh
Output: dist/ATU4K Control.app (locally ad-hoc signed).
The build has no downloaded dependencies. Developer ID signing, notarization and
installer distribution are separate steps; this repository check-in creates no
binary release. The existing bundle identity is retained for preference continuity.

Use
- Connect the USB-C interface, close competing controller clients, select the
  StepperTune serial port and click Connect USB. Find StepperTune uses device
  descriptors; discovery does not open ports or probe the controller.
- USB starts disconnected, and motor controls start off. Connecting requests bank
  and memory status; initial numeric C/L discovery is deferred. Last-known values
  are clearly labelled and are not automatically trusted for movement.
- Enable motor controls and confirm current C/L values against the hardware
  controller. Keep RF off during motor movement. Cached values prefill the dialog
  but still require operator confirmation.
- Jog +/-1 or +/-100, or click a memory and confirm recall. The busy banner remains
  until completion, error or timeout. Disconnect cannot stop movement already sent.
- Save position selects a bank/slot and requires overwrite confirmation. Names are
  software labels, distinct from controller-stored positions.
- Settings exports/imports labels and presentation. Import does not alter hardware
  positions, enable motors or replace the separate last-known-position cache.
- Demo Mode is available through Settings after USB is disconnected.

Current configured limits are C0..9555 and L0..9200 inclusive, supplied manually
for the tested controller. Automatic limit discovery and physical boundary
acceptance remain deferred. Do not assume these limits suit another installation.
No stop command is known. No automatic reconnect, retries, replay or return moves.

DX Caliber integration
DXC DEV0.6.176 supports an independent ATU4K Logger tab. Settings > Share with
DX Caliber enables the loopback companion service on127.0.0.1:51986. This app
remains the sole USB owner. DXC can select banks and request confirmed recalls;
existing connection, motor-enable, bounds, busy and session guards remain active.
Status requests read current software state and do not add USB polling. Stale or
unavailable status disables controls. See docs/DXC-INTERFACE.txt.

Portability
The HTML/CSS/JavaScript model, bounded reply parser and UI are shared. Native Mac
hosting, serial ownership, preference storage and discovery are Swift. A Windows
native host/serial adapter and packaging remain future work; reuse the protocol
and independent native command guards rather than only the UI enable flags.

Offline regressions (no physical hardware required):
    sh test.sh
Three JavaScript suites and nine native suites cover parsing, bounds, settings,
USB pseudo-terminals, cancellation, recovery, memory operations and the isolated
DXC loopback service. Tests never open real USB ports or move physical motors.
User-operated hardware tests have verified jogs, bank synchronization, preset
save/recall, reopening and idle connection recovery. Complete physical boundary,
Windows and final signed-package acceptance are not established by these tests.

Repository scope
Source, tests, icon assets and build documentation only. Personal settings backups,
imported memory-label exports, raw captures, screenshots and compiled apps stay
local. Licensed under the MIT License; see LICENSE.
