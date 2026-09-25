# id: BT-148
# type: feature
# status: done

# Business/User Value: As Ingo I want to go from a decision to the stories behind it and back again
# so that the reasoning and the work are one click apart.

Feature: Jump between a decision and the stories it cites

  Scenario: Follow a decision to its stories
    Given a decision that cites stories APP-001 and APP-002
    When Ingo views its card or detail view
    Then each story id links to that story on the board

  Scenario: Follow a story back to its decisions
    Given a story cited by a decision
    When Ingo views that story
    Then the decision is shown as related

  Scenario: Another project's ids are not linked
    Given a decision citing a story from another project
    When Ingo views its card
    Then that id is shown as plain text rather than a broken link

  Scenario: Supersession can be followed
    Given a decision that supersedes one record and is superseded by another
    When Ingo views it
    Then each of those records is a link
