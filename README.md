# Contact Photos

Create contacts for companies that text users and attach a company photo/logo.

## Secrets and Firebase config

This repository is set up to keep Firebase keys/config out of source control.

### Local development setup
1. Download Firebase config files from your Firebase project:
   - `android/app/google-services.json`
   - `ios/Runner/GoogleService-Info.plist`
2. Place them in those exact paths locally (they are gitignored).
3. Run the app as normal (`flutter run`).

### GitHub secrets setup
Add these repository secrets (Base64-encoded file contents):
- `ANDROID_GOOGLE_SERVICES_JSON_B64`
- `IOS_GOOGLE_SERVICE_INFO_PLIST_B64`

Encode files:
```bash
base64 -i android/app/google-services.json | pbcopy
base64 -i ios/Runner/GoogleService-Info.plist | pbcopy
```

Decode them in GitHub Actions before build:
```bash
python3 - <<'PY'
import base64, os, pathlib
pathlib.Path("android/app").mkdir(parents=True, exist_ok=True)
pathlib.Path("ios/Runner").mkdir(parents=True, exist_ok=True)
pathlib.Path("android/app/google-services.json").write_bytes(
    base64.b64decode(os.environ["ANDROID_GOOGLE_SERVICES_JSON_B64"])
)
pathlib.Path("ios/Runner/GoogleService-Info.plist").write_bytes(
    base64.b64decode(os.environ["IOS_GOOGLE_SERVICE_INFO_PLIST_B64"])
)
PY
```

### Important
If keys have ever been committed, rotate them in Firebase/GCP and consider rewriting git history before making the repository public.
