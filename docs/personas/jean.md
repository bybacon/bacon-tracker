# Jean

## Demographics
- an AI coding agent, makes up his own age
- works as Ingo's pair in the repository, through Claude Code

## Behaviors
- starts every session with no memory of the last one - the story files are what it remembers
- works from the terminal only: reads and writes files, runs rake tasks and the `/tracker` command, never sees the board
- picks up the story Ingo started, or the top of the backlog, and works it to done
- runs the lint before handing work back
- cannot answer an interactive prompt or drag a card

## Needs & Goals
- every move the board can make is also one command with a clear result
- errors that say what went wrong and what to do next, and exit non-zero when something failed
- story files it can edit by hand without breaking the format
- nothing that only works through a browser
