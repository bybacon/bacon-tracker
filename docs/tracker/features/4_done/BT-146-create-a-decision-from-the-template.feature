# id: BT-146
# type: feature
# status: done

# Business/User Value: As Ingo I want to create a decision from the template
# so that it gets a correct id and lands in the right place.

Feature: Create a decision from the template

  Scenario: Create a decision
    Given a project with a decisions folder
    When Ingo creates a decision titled "Adopt a queue"
    Then a record like APP-ADR-0001-adopt-a-queue.md appears in the proposed folder
    And it has the next free id and the sections from the project's decision template
    And it is added to the end of the list of proposed decisions

  Scenario: Ids are never reused
    Given decisions already exist up to APP-ADR-0017
    When two decisions are created at the same moment
    Then they get different ids
    And neither reuses an existing one

  Scenario: Create is offered on the proposed column
    When Ingo views the decisions board
    Then the create button appears on the proposed column only

  Scenario: A project without a template still works
    Given a decisions folder with no template
    When Ingo creates a decision
    Then the record is created with the default sections

  Scenario: A new decision passes the lint
    When Ingo creates a decision
    Then it is marked proposed with today's date and its title as the heading
    And rake "decision:lint" reports nothing for it
