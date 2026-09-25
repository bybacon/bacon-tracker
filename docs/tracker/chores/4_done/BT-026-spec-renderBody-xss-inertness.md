---
id: BT-026
type: chore
status: done
---

Title: Test that story text cannot inject scripts into the board

**Description:**
The board turns story bodies into highlighted Gherkin or formatted Markdown in the browser, and that step is all that stops a story's text from running as script. It was correct, but nothing tested it, so a well-meant simplification could open a hole without any test failing. A test now creates a story whose title and body contain script and image-tag payloads and checks they stay inert. Moving the renderers somewhere they can be tested directly is a larger, separate piece of work.

**Resources:**
- lib/bacon_tracker/server.rb
- spec/bacon_tracker/server_spec.rb
