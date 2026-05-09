# Athena Rules Engine

*A practical CoffeeScript rules engine*

[![Hippocratic License HL3-CORE](https://img.shields.io/static/v1?label=Hippocratic%20License&message=HL3-CORE&labelColor=5e2751&color=bc8c3d)](https://firstdonoharm.dev/version/3/0/core.html)

Athena is a reactive rules engine that allows you to define conditions and actions that respond to state changes.

## Installation

Use your favorite package manager:

```bash
npm install @dashkite/athena
```

## Usage

Define conditions, actions, and rules to create a reactive system.

```coffeescript
import Athena from "@dashkite/athena"

athena = Athena.make()

athena.condition "is-happy", -> @mood == "happy"
athena.action "celebrate", -> console.log "Yay!"

athena.rules
  "celebrate": "is-happy"

state = mood: "happy"
for await event from athena.apply state
  console.log event
```

## Status

Not suitable for production use. Please report any issues on the [GitHub repository](https://github.com/dashkite/athena).
