---
id: BT-038
type: chore
status: done
---

Title: Stop the menu bar app from killing unrelated servers

**Description:**
Each time the menu bar app started the dashboard, it force-killed whatever process was using the dashboard's port. That port is a common default for local web servers, so Ingo could lose an unrelated dev server without warning and without it getting a chance to shut down cleanly. The app now stops only the server it started itself, asks it to shut down before forcing it, and shows in the menu when the port is taken by something else.

**Resources:**
- bacon-tracker-menu/Sources/BaconTrackerMenu/ServerManager.swift
