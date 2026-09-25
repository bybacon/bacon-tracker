---
id: BT-020
type: chore
status: done
---

Title: Use one HTML escaper on the board and test it

**Description:**
The board had two nearly identical escaping helpers, one for Gherkin stories and one for Markdown, and only one of them escaped quotes. The weaker one was safe only because of how the Markdown output happened to be built, which nobody would see before their next edit. The board now uses the stricter escaper everywhere, and tests check that script tags, HTML and entities in a story render as plain text. This builds on the page rendering tests from BT-019.

**Resources:**
- lib/bacon_tracker/server.rb
- spec/bacon_tracker/server_spec.rb
- BT-019
