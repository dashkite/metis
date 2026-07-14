# @dashkite/athena

*A practical CoffeeScript rules engine*

[![Hippocratic License HL3-CORE](https://img.shields.io/static/v1?label=Hippocratic%20License&message=HL3-CORE&labelColor=5e2751&color=bc8c3d)](https://firstdonoharm.dev/version/3/0/core.html)

Athena is a reactive rules engine that allows developers to define conditions and actions that respond to state changes.

## Features

- Reactive rules execution engine
- Define arbitrary conditions and actions
- Resolve rules until a stable state is achieved
- Written in CoffeeScript

## Installation

Use your favorite package manager:

```bash
pnpm install @dashkite/athena
```

## Usage

Define conditions, actions, and rules to create a reactive system.

```coffeescript
import Athena from "@dashkite/athena"

athena = Athena.make()
  .condition [ "is-happy", -> @mood == "happy" ]
  .action [ "celebrate", -> console.log "Yay!" ]
  .rules
    "celebrate": [ "is-happy" ]

state = mood: "happy"
for await event from athena.start state
  console.log event
```

## Other Resources

- [Recipes](docs/recipes.md)
- [Reference](docs/reference.md)
- [Technical Notes](docs/technical-notes.md)
- [Testing](docs/testing.md)
