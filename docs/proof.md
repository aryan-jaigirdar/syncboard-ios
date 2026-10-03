# Local proof record

Recorded 2026-10-03.

| Check | Actual result |
| --- | --- |
| Swift Testing core suite | 10 tests passed, including 3 complete-draft export cases |
| Portable protocol fixture | Swift matches the expected state for all 10 server mutation types |
| Native app | Unsigned simulator build succeeded with Xcode 26.6 / Swift 6.3.3 |
| Live XCTest | 1 offline/relaunch/server-confirmation journey passed on iPhone 17, iOS 26.5 |
| Hosted CI | Configured; not run |
| Physical device / signed release | Not tested |

The live test starts with a fresh board created through the real HTTP API. It launches the native app, enables Work offline, asserts the switch value and Offline status, creates a card, and asserts one pending change is saved. It then terminates the process and launches a new process. It then joins through an independent WebSocket and asserts the authoritative snapshot has exactly one matching card. The local server includes the durable-receipt changes in the paired repository.

An earlier journey tapped the offline switch without asserting its value; its passing result was insufficient evidence. The final test checks the enabled switch, Offline status, and saved pending count. The final run passed after presence cleanup and single-scene configuration.

The retained XCTest attachments are [the offline draft](images/ios-offline.png) and [the reconnected card](images/ios-reconnected.png). The [live seeded board](images/ios-live.png) is a separate real simulator screenshot.

An initial test build mixed x86_64 app linking with an arm64 Swift package object. Debug now builds only the active architecture. The passing local test selected `ARCHS=arm64` on the Apple Silicon simulator. This was a build configuration correction, not a passing first attempt.

The result bundle and build log stay in ignored `.build-output` storage. The committed screenshots and test source make the result inspectable without claiming remote CI, distribution, load testing, or physical-device validation.

The CI runner label follows [GitHub's macOS runner documentation](https://docs.github.com/en/actions/reference/runners/github-hosted-runners). CI performs core tests, generator consistency, and a simulator build. It does not start the paired backend or run the live UI journey.
