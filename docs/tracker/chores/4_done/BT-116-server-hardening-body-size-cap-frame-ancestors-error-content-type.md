---
id: BT-116
type: chore
status: done
---

Title: Harden the server with a body size cap, framing protection and consistent errors

**Description:**
The board server runs on localhost, but it still needed a few protections
before a public release. A huge request could exhaust its memory, another
site could embed the board in a frame to trick clicks, and some API errors
came back as HTML rather than JSON. Closing these gaps keeps Ingo's board
safe and gives Jean predictable error responses.

**Resources:**
- lib/bacon_tracker/server.rb
- BT-085

- [x] Oversized requests are rejected early
- [x] The board cannot be embedded in another site's frame
- [x] API errors return a consistent content type
