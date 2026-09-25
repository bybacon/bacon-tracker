# id: BT-151
# type: feature
# status: done

# Business/User Value: As Ingo I want to see which docs changed recently
# so that I can catch up on a project without reading everything.

Feature: See what changed recently in docs

  Scenario: Recently changed pages
    Given a project's docs kept in git
    When Ingo opens its docs
    Then recently changed pages are listed newest first
    And each shows when it changed

  Scenario: Only real edits count
    Given a file that a checkout touched but nobody edited
    When Ingo views the recently changed list
    Then that file is not listed

  Scenario: A project not kept in git
    Given a project's docs that are not in a git repository
    When Ingo opens its docs
    Then the recently changed list is left out and the rest of the page works
