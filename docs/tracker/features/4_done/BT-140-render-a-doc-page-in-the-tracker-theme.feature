# id: BT-140
# type: feature
# status: done
# blocked_by: BT-139

# Business/User Value: As Ingo I want doc pages shown in the tracker's own theme
# so that the docs and the board feel like one product.

Feature: Render a doc page in the tracker theme

  Scenario: Pages share the board's look
    Given a doc page with headings, a table and a code block
    When Ingo previews it
    Then it uses the board's colours and type
    And it follows the light or dark theme currently chosen

  Scenario: Relative links open inside the browser
    Given a doc page linking to "../decisions/accepted/APP-ADR-0001-use-postgres.md"
    When Ingo follows that link
    Then the linked page opens in the docs browser rather than as a download or an error

  Scenario: Links to files that are not pages
    Given a doc page linking to a PNG image
    When Ingo follows that link
    Then Ingo is offered to reveal or open the file rather than shown a broken preview

  Scenario: Task lists show as checkboxes
    Given a doc page with "- [ ]" and "- [x]" lines
    When Ingo previews it
    Then they show as checkboxes rather than brackets

  Scenario: Links that leave the docs are refused
    Given a doc page with a relative link that climbs out of the docs folder
    When Ingo follows that link
    Then it is refused rather than shown
    And the refusal names the page the link came from

  Scenario: The page endpoint is documented
    When Ingo reads docs/api.md
    Then it describes the request and response for a rendered page
