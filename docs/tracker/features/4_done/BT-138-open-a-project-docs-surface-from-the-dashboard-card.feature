# id: BT-138
# type: feature
# status: done

# Business/User Value: As Ingo I want each project card on the dashboard to offer its board and its docs
# so that I can reach either one without remembering which a project has.

Feature: Open a project's docs from the dashboard card

  Scenario: A project with a board and docs offers both
    Given a project with stories and a docs folder
    When Ingo views the dashboard
    Then its card offers "open tracker" and "open docs"

  Scenario: A project without docs is unchanged
    Given a project with no docs folder
    When Ingo views the dashboard
    Then its card offers only the board

  Scenario: A docs-only project shows docs counts
    Given a project with a docs folder and no stories
    When Ingo views the dashboard
    Then its card shows how many pages and decisions it has and how many decisions are proposed
    And it shows no progress bar or story counts

  Scenario: Clicking the card opens the only surface
    Given a project with only a board or only docs
    When Ingo clicks the card itself
    Then that surface opens
