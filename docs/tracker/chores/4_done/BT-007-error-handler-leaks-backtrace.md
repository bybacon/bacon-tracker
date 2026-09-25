---
id: BT-007
type: chore
status: done
---

Title: Keep internal details out of server error responses

**Description:**
When the server hit an unexpected error, the response body carried the error class, message and a stack trace with absolute file paths. That exposes the local filesystem and does not match the plain error shape every other failure uses. The server still logs the full details to the terminal, and the client now gets a short, consistent error message.

**Resources:**
- lib/bacon_tracker/server.rb
