# id: BT-139
# type: feature
# status: done

# Business/User Value: As Ingo I want to browse a project's documentation in Finder-style columns
# so that I can move through folders and land on a page without losing my place.

Feature: Browse docs in Finder-style columns

  Scenario: Folders and pages in columns with a preview
    Given a docs folder with subfolders and pages
    When Ingo opens the docs
    Then the first column lists the subfolders and pages together
    And selecting a folder opens its contents in the next column
    And selecting a page shows it in the preview on the right

  Scenario: Deep folders push columns to the left
    Given a page nested three folders deep
    When Ingo selects through to it
    Then the columns scroll left so the preview stays visible

  Scenario: Only readable pages are listed
    Given a folder containing "guide.md", "notes.markdown", "raw.txt", "diagram.png" and "data.json"
    When Ingo views that folder
    Then only "guide.md", "notes.markdown" and "raw.txt" are listed

  Scenario: Housekeeping files and the stories are hidden
    Given a decisions folder containing ".next-id", "proposed.md" and "_template.md"
    And the project's stories sit inside its docs folder
    When Ingo browses the docs
    Then none of those files and none of the stories are listed

  Scenario: Paths outside the project are refused
    When a page is requested from outside the project's docs
    Then the request is refused and no file content is returned

  Scenario: The docs endpoints are documented
    When Ingo reads docs/api.md
    Then it describes the request and response for browsing the docs
