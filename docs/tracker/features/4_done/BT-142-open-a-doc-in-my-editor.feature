# id: BT-142
# type: feature
# status: done
# blocked_by: BT-139

# Business/User Value: As Ingo I want to open a doc in my own editor from the browser
# so that I never have to write prose in a browser text box.

Feature: Open a doc in my editor

  Scenario: Open the selected page in the editor
    Given a page selected in the docs browser
    When Ingo chooses "open in editor"
    Then the file opens in Ingo's configured editor

  Scenario: Offered wherever a file is shown
    Given a decision card on the decisions board
    When Ingo opens its actions
    Then "open in editor" is offered there too

  Scenario: No editing inside the browser
    When Ingo views any doc page
    Then there is no editable text field for its body
