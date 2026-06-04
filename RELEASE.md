# Release Checklist

Use this document for every production release. Complete each section in order — do not proceed to the next section until all items in the current one are checked.

---

## 1. Code Readiness

- [ ] All P0 and P1 issues resolved and merged to `main`
- [x] `flutter analyze --fatal-infos` passes locally
- [x] `flutter test` passes locally with no skipped tests
- [x] CI is green on `main` (analyze, test, and sanity jobs)
- [ ] No placeholder bundle identifiers (`com.example`) in iOS or Android config
- [ ] `READ_SMS` (or any high-scrutiny permission) removed or policy-justified
- [ ] Release signing configured for Android (not debug keys)
- [ ] Firebase configs match the production project

## 2. Store Assets

- [ ] App icon finalized (1024×1024 PNG for iOS, adaptive icon for Android)
- [ ] Screenshots captured for all required device sizes (iPhone, iPad, Android phone/tablet)
- [ ] App Store Connect metadata complete (name, subtitle, description, keywords, category)
- [ ] Google Play Console listing complete (title, short/full description, category, content rating)
- [ ] Privacy policy URL live and linked in both store listings
- [ ] Terms of service URL live and linked where required

## 3. Compliance & Privacy

- [ ] Privacy policy covers all data collected (contacts, images, analytics)
- [ ] In-app permission disclosures match the privacy policy
- [ ] App Store privacy nutrition labels filled in (App Store Connect → App Privacy)
- [ ] Google Play Data Safety form completed
- [ ] IAP product `unlimited_contacts` approved in both stores (issue #18)

## 4. Build & Sign

### Android

- [ ] `flutter build appbundle --release` succeeds
- [ ] AAB signed with production keystore (not debug)
- [ ] `bundletool` smoke-test: install on a physical device from the AAB

### iOS

- [ ] `flutter build ipa --release` succeeds
- [ ] IPA signed with App Store distribution certificate
- [ ] Uploaded to App Store Connect via Xcode or Transporter
- [ ] TestFlight build passes Apple processing

## 5. Pre-Launch Testing

- [ ] Smoke test on a physical iOS device (golden path: search → image → create contact)
- [ ] Smoke test on a physical Android device
- [ ] Paywall appears on 4th contact creation attempt
- [ ] Successful IAP unlocks unlimited creation
- [ ] Restore Purchases works on a reinstalled build
- [ ] Permission flows work correctly (contacts denied → re-request)
- [ ] Offline / no-network state does not crash the app

## 6. Go / No-Go Gate

All of the above must be checked **and** the following people have signed off:

| Name | Role        | Sign-off |
| ---- | ----------- | -------- |
|      | Product     | ☐        |
|      | Engineering | ☐        |

**Decision:** ☐ Go &nbsp;&nbsp; ☐ No-Go

---

## 7. Release

- [ ] Android: promote AAB from internal track → production in Play Console
- [ ] iOS: submit for App Review in App Store Connect
- [ ] Tag the release commit: `git tag -a vX.Y.Z -m "Release vX.Y.Z"`
- [ ] Push the tag: `git push origin vX.Y.Z`
- [ ] Create a GitHub Release with changelog

---

## Hotfix Process

1. Branch from the release tag: `git checkout -b hotfix/vX.Y.Z+1 vX.Y.Z`
2. Apply the minimal fix and bump `version` in `pubspec.yaml`
3. Follow sections 4–7 above
4. Merge the hotfix branch back to `main`

## Rollback

- **Android:** Go to Play Console → Release → select prior release → Re-release
- **iOS:** Contact App Store support — iOS releases cannot be rolled back automatically; expedited review may be requested for a fix

## Support & Incidents

- First-response: check Firebase Crashlytics for stack traces
- Severity triage: P0 = data loss or crash on launch, P1 = broken core flow, P2 = cosmetic
- P0/P1 incidents: hotfix within 24 h, notify users via App Store release notes
