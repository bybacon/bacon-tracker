# id: BT-070
# type: feature
# status: done

# Business/User Value: As Ingo I want to open a single story in a larger view
# so that I can read its full body, subtasks and fields without squinting at a card or leaving the board.

Feature: Story detail view

  Scenario: Open a story in a larger view
    Given a board with several stories
    When Ingo opens a story's detail view
    Then its title, body, subtasks and fields are shown at a readable size
    And the board stays behind it, ready to return to

  Scenario: Close the detail view
    Given a story open in the detail view
    When Ingo closes it
    Then Ingo is back on the board where the detail view was opened

  Scenario: Long stories stay readable
    Given a story with a long body and many subtasks
    When Ingo opens its detail view
    Then the content scrolls inside the view and the board layout is unaffected

  Scenario: Subtasks can be ticked in the detail view
    Given a story with subtasks open in the detail view
    When Ingo ticks a subtask
    Then the change is saved just as it is from the card
