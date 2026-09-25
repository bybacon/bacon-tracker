# id: BT-144
# type: feature
# status: done

# Business/User Value: As Ingo I want to see decisions as a board grouped by status
# so that I can tell at a glance what is proposed and what is in force.

Feature: See decisions as a board grouped by status

  Scenario: One column per status
    Given decision records in several status folders
    When Ingo opens the decisions board
    Then there are columns for proposed, accepted, rejected, deprecated and superseded
    And each card sits in the column named by its folder

  Scenario: Past decisions start collapsed
    Given records that are rejected, deprecated and superseded
    When Ingo opens the decisions board
    Then those three columns are collapsed
    And expanding one shows its cards

  Scenario: The accepted column pages like the done column
    Given more accepted records than fit on one screen
    When Ingo opens the decisions board
    Then the accepted column is paged the way the done column is

  Scenario: A card says what the record is
    When Ingo views the decisions board
    Then each card shows its id, title and date
    And a superseded card links to the record that replaced it

  Scenario: No decisions folder, no decisions board
    Given a project whose docs have no decisions folder
    When Ingo opens its docs
    Then no decisions board is offered

  Scenario: The decisions endpoint is documented
    When Ingo reads docs/api.md
    Then it describes the request and response for listing decisions
