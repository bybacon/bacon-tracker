# id: BT-145
# type: feature
# status: done

# Business/User Value: As Ingo I want to move a decision through its statuses on the board
# so that the file and its fields stay correct without editing them by hand.

Feature: Move a decision through its statuses from the board

  Decisions only move forward. To reverse one, it is superseded by a new record.

  Scenario: Accept a proposed decision
    Given Leonor has proposed a decision
    When Ingo drags its card to accepted
    Then the file moves to the accepted folder with its status and date updated
    And it is removed from the list of proposed decisions

  Scenario: Superseding asks for the replacement
    Given an accepted decision
    When Ingo drags its card to superseded
    Then Ingo is asked which decision replaces it
    And nothing moves until one is named

  Scenario: Superseding updates both records
    Given accepted decisions APP-ADR-0001 and APP-ADR-0002
    When Ingo supersedes APP-ADR-0001 by APP-ADR-0002
    Then APP-ADR-0001 is superseded and names APP-ADR-0002 as its replacement
    And APP-ADR-0002 names APP-ADR-0001 as the record it supersedes
    And either both records change or neither does

  Scenario: Superseding by another project's decision
    Given an accepted decision
    When Ingo supersedes it by a decision from another project
    Then only this project's record is changed
    And Ingo is told the other project's record was not updated

  Scenario: A replacement that does not exist is refused
    Given an accepted decision
    When Ingo supersedes it by an id in this project that has no record
    Then the move is refused and neither record changes

  Scenario: Moving backwards is refused
    Given an accepted decision
    When Ingo drags it back to proposed
    Then the move is refused
    And Ingo is told to supersede it with a new decision instead
