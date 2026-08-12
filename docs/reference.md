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

### start

$start:( state ) \rightarrow async\_generator$
$start:( state, evaluator, delegator ) \rightarrow async\_generator$
$start:( state, options ) \rightarrow async\_generator$

Applies the registered rules to the given state utilizing an iterator evaluation form. Yields execution events as state mutations occur. `options` allows configuring `mode` ("sync" or "async") and `delegator`.

### run

$run:( state ) \rightarrow state$
$run:( state, evaluator ) \rightarrow state$
$run:( state, options ) \rightarrow state$

Evaluates the rules engine to equilibrium, returning the final state statelessly (or a Promise resolving to it). `options` allows configuring `mode` ("sync" or "async").

### each

$each:( selector ) \rightarrow aggregator$

Returns a new `Aggregator` scope bound to the target collection selector function.

## Aggregator

### condition

$condition:( specifier ) \rightarrow aggregator$
$condition:( name, run ) \rightarrow aggregator$
$condition:( name, conditions, run ) \rightarrow aggregator$

Registers a local item-level condition on the `Aggregator` instance (`@ = item`, `(state)` parameter). Local conditions are scoped exclusively to the aggregator and do not pollute the parent engine condition registry.

### action

$action:( specifier ) \rightarrow engine$
$action:( name, run ) \rightarrow engine$
$action:( name, conditions, run ) \rightarrow engine$

Registers an iterative action for the collection elements matching specified local and global conditions (`@ = item`, `(state)` parameter). Returns the parent `Athena` instance to resume top-level rulebase chaining.

