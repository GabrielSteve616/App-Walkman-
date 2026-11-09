# Walkmen Android extension

Based on audio_service 0.18.19, MIT; original LICENSE retained.

Android AudioService adds an optional notification decoration hook, access to the active media-session token for local widgets, and a one-second visual tick only during playback while the screen is interactive. Pause and destruction cancel the tick. Original media transport, session, wake lock, service lifecycle and default notification fallback are preserved. No upstream Dart behavior was changed.

Custom notification content may be replaced by Android System UI, particularly on Android 13+ and manufacturer media panels. Cover, progress and native controls remain available there.
