# id: BT-152
# type: feature
# status: done

# Business/User Value: As Ingo I want to see what links to a doc
# so that I can tell whether other pages still rely on it before I change it.

Feature: See what links to a doc

  Scenario: Links to a page
    Given two pages linking to "vocabulary.md"
    When Ingo views vocabulary.md
    Then both pages are listed under what links here

  Scenario: Links to a decision
    Given a decision cited by another decision
    When Ingo views the cited decision
    Then the citing decision is listed

  Scenario: Nothing links to the page
    Given a page with no links to it
    When Ingo views it
    Then the section says that nothing links here
