# id: BT-141
# type: feature
# status: done
# blocked_by: BT-139

# Business/User Value: As Ingo I want a doc to open in the same detail view stories use
# so that reading a long page is not squeezed into the preview.

Feature: Open a doc in the detail view

  Scenario: Expand a page into the detail view
    Given a page shown in the preview
    When Ingo expands it
    Then the page opens in the detail view

  Scenario: Only one detail view at a time
    Given a page open in the detail view
    When Ingo expands a second page
    Then the second page replaces the first
    And only one detail view is ever on screen

  Scenario: Closing returns to the same place
    Given a page open in the detail view
    When Ingo closes it
    Then the docs browser shows the same folder and selection as before

  Scenario: A decision opens in the same view
    Given a decision card on the decisions board
    When Ingo expands it
    Then it opens in the detail view
    And its fields are shown as labelled values rather than raw frontmatter
