# id: BT-181
# type: feature
# status: done

# Business/User Value: As Ingo I want a story's filename to spell out umlauts and keep accented
# letters, so that a German or French title is still readable in the file list and in a URL.

Feature: A story file is named with umlauts spelled out

  Scenario: An umlaut is spelled out
    Given Ingo creates a story called "Datenschutzerklärung"
    When the file is named
    Then its name ends in "datenschutzerklaerung"
    And not in "datenschutzerkl-rung"

  Scenario: ß becomes ss
    Given Ingo creates a story called "Größe der Straße"
    When the file is named
    Then its name ends in "groesse-der-strasse"

  Scenario: Other accents are dropped
    Given Ingo creates a story called "Café résumé"
    When the file is named
    Then its name ends in "cafe-resume"

  Scenario: Existing files keep their names
    Given a story file created before this change
    When Ingo opens the board
    Then the file is not renamed until the story's title is changed

  Scenario: Jean follows the same rule by hand
    Given no Rakefile is available
    When Jean creates a story from the /tracker command
    Then the filename spells out umlauts the same way the board would
