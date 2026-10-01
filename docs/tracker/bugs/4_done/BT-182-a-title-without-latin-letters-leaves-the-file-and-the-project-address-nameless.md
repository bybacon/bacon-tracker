---
id: BT-182
type: bug
status: done
---

Title: A title without Latin letters leaves the file and the project address nameless

**Currently:**
A title written entirely in, say, Japanese has nothing the filename rule
keeps. A story then gets the file name "untitled", which is wrong because
the story does have a title. A decision record gets the same. A project
on the dashboard whose heading has no Latin letters gets an empty address,
so its board link points at "/projects/" and a second such project at
"/projects/-2".

**Expected:**
A name that cannot be turned into a filename gets a placeholder that says
what happened and asks to be replaced: "non-latin-REPLACE-ME". Story
files, decision records and project addresses all use it. The card still
shows the real title from the file. A project with such a heading and no
namespace of its own is still skipped with a warning, because a namespace
must not be guessed from the placeholder.

**STEPS TO REPRODUCE:**
1. Create a story called "日本語"
2. The file is called BT-NNN-untitled.md although the story has a title
3. Add a project "## 日本語" with a namespace to dashboard.md
4. Its board link on the dashboard is "/projects/"

**REFERENCE:**
BT-095 (the earlier "untitled" fallback), BT-180
