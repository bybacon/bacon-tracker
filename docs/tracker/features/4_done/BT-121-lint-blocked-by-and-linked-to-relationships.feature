# id: BT-121
# type: feature
# status: done
# size: M
# linked_to: BT-123

# Business/User Value: As Ingo I want lint to check blocked_by and linked_to
# so that a story never sits blocked by work that already shipped.

Feature: Lint blocked_by and linked_to relationships

  A blocked badge renders whether or not the blocker is still real. Lint
  reads the relationships and says which ones no longer hold, and what to do
  about each.

  Scenario: A blocker that already shipped
    Given APP-002 is blocked by APP-001
    And APP-001 is done
    When Ingo runs rake story:lint
    Then it reports that APP-002 waits on APP-001, which is done
    And the command fails

  Scenario: A reference to a story that does not exist
    Given APP-002 is linked to APP-999
    And there is no story APP-999
    When Ingo runs rake story:lint
    Then it reports the dangling reference
    And the command fails

  Scenario: Stories that wait on each other
    Given APP-002 is blocked by APP-003
    And APP-003 is blocked by APP-002
    When Ingo runs rake story:lint
    Then it reports the cycle with both stories
    And the command fails

  Scenario: Work started while still blocked is only a note
    Given APP-002 is started and blocked by APP-001
    And APP-001 is still in the backlog
    When Ingo runs rake story:lint
    Then it notes that APP-002 is started while blocked
    But the command does not fail on that alone

  Scenario: Waiting on something outside the tracker is fine
    Given APP-002 is blocked by "sinatra-5.x"
    When Ingo runs rake story:lint
    Then it says nothing about it

  Scenario: Finished stories are history, not findings
    Given APP-002 is done and was blocked by APP-001, also done
    When Ingo runs rake story:lint
    Then it says nothing about APP-002

- [x] Lint reports blockers that already shipped
- [x] Lint reports references to stories that do not exist
- [x] Lint reports stories that block each other
- [x] Started-while-blocked is reported without failing the command
- [x] The checks are described in docs/linting.md and the /tracker command
