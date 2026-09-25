---
id: BT-073
type: chore
status: done
---

Title: Point the BaconTrackerMenu app at the renamed tracker-dashboard binary

**Description:**
After BT-072 renamed the dashboard executable, the menu bar app still
looked for the old name. That stopped it from recognising and clearing its
own stale server. The app now matches the new name. If a saved script path
points at the removed file, it asks Ingo to choose the script again rather
than failing silently. Its menu labels and docs use the new name too.

**Resources:**
- bacon-tracker-menu (separate repository)
- BT-072
