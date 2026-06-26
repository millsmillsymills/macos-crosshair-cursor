# Permission-free input: global NSEvent mouse monitor + Carbon hotkey

The app ships with zero TCC permission prompts. Cursor tracking uses `NSEvent.addGlobalMonitorForEvents` on `.mouseMoved` + the `.*MouseDragged` masks, reading `NSEvent.mouseLocation` in the handler — mouse events through this API require **no** permission (only key-related events would). The toggle hotkey uses Carbon `RegisterEventHotKey`, which is system-wide and also permission-free, rather than an `NSEvent` keyDown global monitor (which *would* trigger the Accessibility prompt).

We explicitly rejected `CGEventTap` for tracking: it costs an Input Monitoring prompt and buys nothing here. We verified the premise that motivated considering it was false — Secure Event Input suppresses only *keyboard* events, not mouse-moved, so the global monitor does not "freeze" during password entry; if anything, `CGEventTap` is the API that gets starved during Secure Event Input.

Accepted limitation: the crosshair stops updating while another app has actively captured/hidden the cursor (e.g. a full-screen game in relative-mouse mode) — but there is no visible cursor to locate in that state, so the crosshair is moot.
