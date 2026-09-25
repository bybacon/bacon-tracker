---
id: BT-021
type: chore
status: done
---

Title: Build the card header in one place

**Description:**
A card's header, with its id badge, extra badges and edit and reveal buttons, was built once when the card first rendered and again after a save. The two copies had already drifted: after saving, the reveal button once stopped working. Building the header from one shared piece of code means a new badge or button only has to be added once and behaves the same before and after an edit.

**Resources:**
- lib/bacon_tracker/server.rb
