---
id: BT-056
type: bug
status: done
---

Title: A damaged id counter reissues ids that are already taken

**Currently:**
When the `.next-id` file holds something unreadable, such as the git
conflict markers left after Ingo's and Leonor's branches both created
stories, the tracker quietly starts counting from 1 again.
The next story Jean creates gets an id that another story already has, and
nothing warns about it. Duplicate ids then put other stories at risk when
they are moved between stages.

**Expected:**
A new story always gets an id higher than any story already on disk, even
when the counter file is missing, stale or damaged.

**STEPS TO REPRODUCE:**
1. Write git conflict markers into `.next-id`
2. Create a story with rake "story:feature[Some title]"
3. The new story reuses an id that already exists

**REFERENCE:**
- BT-048
