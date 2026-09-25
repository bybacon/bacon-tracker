# id: BT-045
# type: feature
# status: done

# Business/User Value: As Ingo I want to break a story into checkable subtasks
# so that I can follow progress inside one story without splitting it into many tiny ones.

Feature: Subtask support in stories

  A subtask is a "- [ ]" line in the story body. The board counts them
  and lets them be ticked off, and the file stays plain Markdown.

  Scenario: Add subtasks to a story
    Given a story APP-001
    When Jean adds a checklist of subtasks to the story body
    Then each subtask is kept as a checkbox line in the story file
    And the subtasks are unchanged after the story is saved from any interface

  Scenario: Tick off a subtask
    Given a story with an unchecked subtask
    When Ingo ticks the subtask
    Then the subtask shows as done
    And the story stays in the same stage

  Scenario: See subtask progress on the card
    Given a story with 4 subtasks, 1 of them done
    When Ingo views the board
    Then the story card shows "1/4"

  Scenario: A story without subtasks shows no progress
    Given a story with no subtasks
    When Ingo views the board
    Then its card shows no subtask progress
