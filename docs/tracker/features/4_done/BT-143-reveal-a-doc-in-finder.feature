# id: BT-143
# type: feature
# status: done
# blocked_by: BT-139

# Business/User Value: As Ingo I want to reveal a doc in Finder
# so that I can act on the real file the way I already can from the board.

Feature: Reveal a doc in Finder

  Scenario: Reveal a page
    Given a page selected in the docs browser
    When Ingo chooses "reveal"
    Then Finder opens with that file selected

  Scenario: Reveal a folder
    Given a folder selected in the docs browser
    When Ingo chooses "reveal"
    Then Finder opens with that folder selected

  Scenario: Reveal stays inside the project
    When a reveal is requested for a path outside the project's stories and docs
    Then the request is refused
    And no other project's files can be reached
