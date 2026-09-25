# id: BT-075
# type: feature
# status: done

# Business/User Value: As Jean I want to set every field when I create a story and to edit its body plainly
# so that creating from the CLI or /tracker reaches the same fields as editing, with no surprises.

Feature: Set any field at create time and edit the body

  This builds on BT-074: creating a story takes the same field=value list
  as editing one, and body editing is clear about what it can and cannot do.

  Scenario: Set any field when creating a story
    When Jean runs rake "story:bug['Crash',size=S,assignee=AB,blocked_by=APP-002,APP-005]"
    Then a new bug is created with all of those fields set
    And "/tracker new" accepts the same field=value list

  Scenario: A bad field at create time still reports the new story
    When Jean runs rake "story:feature['X',size=XL]"
    Then the command reports that the story was created but the size could not be set, because size must be S, M or L
    And the new story is in the icebox under the id it was given

  Scenario: Replacing the body comes with a warning
    Given a story APP-001 with a detailed body
    When Jean runs rake "story:edit[APP-001,body=one-line note]"
    Then Jean is warned that body= replaces the whole body
    And the body becomes "one-line note"

  Scenario: Multi-line bodies are pointed elsewhere
    Given a rake argument is a single shell line
    When Jean needs a multi-line body or a subtask checklist
    Then the docs point to /tracker, the board or an editor instead
