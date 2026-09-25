# id: BT-123
# type: feature
# status: done
# size: M

# Business/User Value: As Leonor I want lint findings to appear on the story
# files in a pull request so that I catch tracker drift while reviewing, not
# whenever someone remembers to run lint by hand.

Feature: Lint the tracker in GitHub Actions

  rake story:lint already fails on a finding, so any CI job can run it. With
  LINT_FORMAT=github each finding becomes an annotation on the story file and
  line that caused it, right in the pull request's diff.

  Scenario: A finding fails the pull request's check
    Given a repository whose CI runs rake story:lint
    When Ingo opens a pull request that leaves a blocker that already shipped
    Then the check fails before Leonor starts the review

  Scenario: Findings land on the story file that caused them
    Given LINT_FORMAT=github is set
    When lint finds a problem in APP-004
    Then Leonor sees it on APP-004's file in the pull request, at the offending line

  Scenario: A finding with no single file lands on the file that holds it
    Given LINT_FORMAT=github is set
    When lint finds a backlog line with no story file behind it
    Then the annotation is on backlog.md

  Scenario: A note annotates without failing
    Given the only finding is a story started while blocked
    When the check runs
    Then the pull request shows the note
    And the check passes

  Scenario: Terminal output is unchanged
    Given LINT_FORMAT is not set
    When Ingo runs rake story:lint in a terminal
    Then the output is the plain list it always was

- [x] LINT_FORMAT=github turns each finding into an annotation on its file and line
- [x] Notes annotate without failing; the default output is unchanged
- [x] This repository lints its own tracker on every pull request
- [x] docs/linting.md shows how to add the step to any workflow
