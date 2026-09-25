# id: BT-147
# type: feature
# status: done

# Business/User Value: As Ingo I want to put the proposed decisions in order
# so that it is always clear which decision to take next.

Feature: Reorder the proposed decisions

  Scenario: Reorder by dragging
    Given three proposed decisions
    When Ingo drags one above another
    Then proposed.md lists them in the new order
    And the decision records themselves are unchanged

  Scenario: Position is the priority
    When Ingo reads proposed.md
    Then the first entry is the next decision to take
    And no decision carries a separate priority field

  Scenario: The list keeps itself up to date
    Given proposed.md still lists a decision that has since been accepted
    When any decision changes
    Then the accepted decision is dropped from the list
    And any proposed decision missing from it is added at the end
    And the heading and other lines in proposed.md are kept
