# id: BT-150
# type: feature
# status: done

# Business/User Value: As Ingo I want to search a project's docs
# so that I can find a half-remembered page without guessing which folder it is in.

Feature: Search a project's docs

  Scenario: Search within a project
    Given a project whose docs contain the phrase "append-only"
    When Ingo searches for "append-only"
    Then the matching pages are listed grouped by folder
    And each result shows the matching line in context

  Scenario: Open a result
    When Ingo opens a search result
    Then the docs browser shows that page with the match in view

  Scenario: Decisions are searched too
    Given a decision containing the search term
    When Ingo searches for it
    Then the decision appears in the results alongside the other pages

  Scenario: Hidden files are not searched
    Given a term that appears only in a template file
    When Ingo searches for it
    Then there are no results

  Scenario: Nothing matches
    When Ingo searches for a term that appears nowhere
    Then Ingo is told there are no matches
