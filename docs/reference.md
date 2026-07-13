# Reference

## Data Structures

### Rule Schema

The structure of a rule mapping can be represented by the following JSON Schema:

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "description": "A dictionary mapping action names to their required conditions.",
  "additionalProperties": {
    "anyOf": [
      {
        "type": "string"
      },
      {
        "type": "array",
        "items": {
          "type": "string"
        }
      }
    ]
  }
}
```

## Athena

### make

$make:( options ) \rightarrow engine$

Creates a new Athena engine instance with the provided configuration options.

### conditions

$conditions:( dictionary ) \rightarrow engine$

Registers a dictionary of conditions with the engine instance.

### condition

$condition:( specifier ) \rightarrow engine$
$condition:( name, run ) \rightarrow engine$
$condition:( name, conditions, run ) \rightarrow engine$

Registers a single condition mapping its name to the evaluation function.

### actions

$actions:( dictionary ) \rightarrow engine$

Registers a dictionary of actions with the engine instance.

### action

$action:( specifier ) \rightarrow engine$
$action:( name, run ) \rightarrow engine$
$action:( name, conditions, run ) \rightarrow engine$

Registers a single action mapping its name to the execution function.

### rules

$rules:( dictionary ) \rightarrow engine$

Registers a dictionary mapping actions to their prerequisite conditions.

### apply

$apply:( state, args ) \rightarrow async\_generator$

Applies the registered rules to the given state and yields execution events as state mutations occur.

### run

$run:( state ) \rightarrow engine$

A method for evaluating the rules engine to equilibrium, returning the instance. Executes synchronously unless a condition or action returns a Promise, in which case it transitions to asynchronous execution.
