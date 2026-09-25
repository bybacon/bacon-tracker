# id: BT-074
# type: feature
# status: done

# Business/User Value: As Jean I want to set any story field from the rake CLI
# so that I can do everything the board does without a browser.

Feature: Set story fields from the rake CLI and document subtasks

  Every field the board's edit form can change is also one rake command,
  with the same rules and the same error messages.

  Scenario: Set several fields in one command
    Given a story APP-001 in the backlog
    When Jean runs rake "story:edit[APP-001,size=M,assignee=AB]"
    Then APP-001 is size M and assigned to AB

  Scenario: Name several blockers at once
    Given a story APP-001
    When Jean runs rake "story:edit[APP-001,blocked_by=APP-002,APP-005]"
    Then APP-001 is blocked by both APP-002 and APP-005

  Scenario: Clear a field
    Given APP-001 has a size
    When Jean runs rake "story:edit[APP-001,size=]"
    Then APP-001 has no size

  Scenario: An unknown field is refused
    When Jean runs rake "story:edit[APP-001,colour=blue]"
    Then the command fails and lists the fields that can be edited
    And the story is unchanged

  Scenario: Give a new story a size as it is created
    When Jean runs rake "story:bug[Crash on save,size=S]"
    Then a new bug of size S is created

  Scenario: Subtasks are explained wherever stories are
    When Ingo reads the README, the /tracker command, docs/flow.md or a story template
    Then each explains that "- [ ]" lines in a story are subtasks the board counts and ticks off
    And that they work from every interface, not only the board
