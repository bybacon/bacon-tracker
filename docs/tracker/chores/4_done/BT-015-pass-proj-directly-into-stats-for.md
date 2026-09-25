---
id: BT-015
type: chore
status: done
---

Title: Build each project's stats without searching for it again

**Description:**
The dashboard asks every project for its stats each time the menu bar app polls, and it looked each project up again by name first. With many projects that adds up. Building the stats straight from the project it already has keeps the poll cheap.

**Resources:**
- lib/bacon_tracker/dashboard.rb
