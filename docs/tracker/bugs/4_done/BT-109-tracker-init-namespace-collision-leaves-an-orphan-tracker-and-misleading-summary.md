---
id: BT-109
type: bug
status: done
---

Title: tracker-init with a taken namespace leaves an orphan tracker and a misleading summary

**Currently:**
When Ingo runs `tracker-init` with a namespace another project already
uses, it creates the whole tracker first and only then notices the clash.
It warns and skips adding the project to the dashboard, leaving a tracker
nothing knows about. Its summary still suggests story commands with that
namespace, and following them writes into the other project's tracker.

**Expected:**
`tracker-init` checks for a namespace or path clash before creating
anything, stops with a clear message, and never suggests commands that
would write into another project.

**STEPS TO REPRODUCE:**
1. Have a project with namespace `BCN` already on the dashboard
2. Run `tracker-init --path /new --namespace BCN -y`
3. `/new/tracker` exists but isn't on the dashboard, and the summary's
   commands act on the other project

**REFERENCE:**
-
