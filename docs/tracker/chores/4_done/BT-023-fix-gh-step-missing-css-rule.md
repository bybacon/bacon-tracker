---
id: BT-023
type: chore
status: done
---

Title: Style Gherkin step keywords in the story view

**Description:**
When a feature story is displayed, the step keywords Given, When, Then, And and But were marked up for styling, but no style existed for them. They looked exactly like plain text, unlike every other part of the Gherkin highlighting. The intended look needed confirming, and the keywords now have a matching style, so scenarios are easier for Ingo to scan.

**Resources:**
- lib/bacon_tracker/server.rb
