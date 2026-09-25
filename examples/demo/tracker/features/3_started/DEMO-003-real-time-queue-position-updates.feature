# id: DEMO-003
# type: feature
# status: started
# size: M
# assignee: AV
# linked_to: DEMO-006

Feature: Real-time queue position updates

  Scenario: Position updates live
    Given I am waiting in a queue
    When someone ahead of me is served
    Then my position updates without a page refresh

- [x] Open a WebSocket channel per queue
- [ ] Reconnect automatically on a dropped connection
- [ ] Throttle broadcasts to at most one per second
