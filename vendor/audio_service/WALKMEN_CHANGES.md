# Walkmen Android extension

Based on audio_service 0.18.19, MIT; original LICENSE retained.

Android AudioService adds an optional notification decoration hook, access to the active media-session token for local widgets, and a one-second visual tick only during playback while the screen is interactive. Pause and destruction cancel the tick. Original media transport, session, wake lock, service lifecycle and default notification fallback are preserved. No upstream Dart behavior was changed.

Custom notification content may be replaced by Android System UI, particularly on Android 13+ and manufacturer media panels. Cover, progress and native controls remain available there.

Walkmen 0.9: visual refresh runs only while the activity is visible, at four-second intervals. The standard media notification is restored on activity stop, avoiding background bitmap animation and allowing System UI to manage playback progress. Activity start/stop requests one immediate refresh; audio/session handling remains in the foreground service.

Release resource protection: the app keeps dynamically referenced media icons; the service falls back to the application icon if a configured notification icon cannot be resolved.
