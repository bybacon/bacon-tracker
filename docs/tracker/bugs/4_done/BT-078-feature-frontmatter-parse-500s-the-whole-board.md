---
id: BT-078
type: bug
status: done
---

Title: One malformed feature header takes down the whole board

**Currently:**
If a single `.feature` file has a header line with no space after the
colon, such as `# type:bug` or `# language:en`, the board fails to load
with a server error. Ingo gets no hint of which file caused it. Story files
in Markdown are already protected against this; feature files are not.

**Expected:**
A malformed header line in one feature file is skipped with a warning
naming the file, and the board stays up.

**STEPS TO REPRODUCE:**
1. Add the line `# type:bug` to the header of any feature file
2. Open the board - it fails to load and shows a server error

**REFERENCE:**
- BT-055
