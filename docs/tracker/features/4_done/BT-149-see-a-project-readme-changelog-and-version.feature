# id: BT-149
# type: feature
# status: done

# Business/User Value: As Ingo I want a project's readme, changelog and version up front
# so that I know what the project is before I browse its folders.

Feature: See a project's readme, changelog and version

  Scenario: The readme is the front page
    Given a project with a README.md
    When Ingo opens its docs
    Then the readme is shown as the front page rather than as a file in the folders

  Scenario: The changelog has its own view
    Given a project with a CHANGELOG.md
    When Ingo opens its docs
    Then the changelog is offered as a timeline grouped by version
    And only the newest version is expanded at first

  Scenario: The version is shown as a badge
    Given a project with a VERSION file
    When Ingo opens its docs
    Then the version is shown on the front page and on the project card

  Scenario: The version file is found without configuration
    Given a project whose VERSION file is at "app/VERSION"
    When Ingo opens its docs
    Then the version is read from it
    And a "version:" key in the project's dashboard entry takes precedence when set

  Scenario: Two version files and no setting
    Given a project with both "app/VERSION" and "web/VERSION" and no "version:" key
    When Ingo opens its docs
    Then no version is shown
    And Ingo is told which files were found rather than given a guess

  Scenario: All three are optional
    Given a project with no readme, changelog or version file
    When Ingo opens its docs
    Then the front page simply leaves them out
