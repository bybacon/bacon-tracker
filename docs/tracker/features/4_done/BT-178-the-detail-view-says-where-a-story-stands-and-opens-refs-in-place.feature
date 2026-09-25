# id: BT-178
# type: feature
# status: done

# Business/User Value: As Ingo I want the detail view to show where a story or decision stands
# and to open its references in place, so that I can read and move around from the detail view alone.

Feature: The detail view says where a story stands and opens references in place

  Scenario: A story's detail view names its stage
    Given a story in the backlog
    When Ingo opens its detail view
    Then the view says the story is in the backlog

  Scenario: A decision's detail view names its status
    Given an accepted decision
    When Ingo opens its detail view
    Then the view says the decision is accepted

  Scenario: A relationship badge on a card opens the other story
    Given a card for a story blocked by another story
    When Ingo clicks the blocked-by badge
    Then the blocking story opens in the detail view

  Scenario: A relationship badge in the detail view switches story
    Given a story open in the detail view with a linked story badge
    When Ingo clicks that badge
    Then the detail view shows the linked story without closing
