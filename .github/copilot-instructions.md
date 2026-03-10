# Copilot Instructions for contact_photos

## Architecture Preferences

### Use flutter_hooks Instead of StatefulWidget

When generating Flutter code, prefer `flutter_hooks` for state management over `StatefulWidget`:

- Use `HookWidget` as the base class instead of `StatefulWidget`
- Use hooks like `useState`, `useEffect`, `useRef`, etc. for managing state and lifecycle
- Avoid creating separate `State` classes

**Example:**
final counter = useState(0);
final isLoading = useState(false);
