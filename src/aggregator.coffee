import Generic from "@dashkite/generic"
import { tuple, deferrable } from "./helpers.js"
import Conditions from "./conditions.js"

# evaluates a single condition predicate against an item target
test = deferrable ({ item, state }, entry ) ->
  entry.predicate.call item, state

# executes an action function against an item target
execute = deferrable ({ item, state }, run ) ->
  run.call item, state

# resolves the item collection from state using the selector function
select = deferrable ( selector, state ) ->
  selector.call state, state

# tests whether all conditions in a closure pass for a target item
evaluate = deferrable ( target, [ entry, rest... ]) ->
  if entry?
    test target, entry, ( passed ) ->
      if passed
        evaluate target, rest, ( result ) -> result
      else
        false
  else
    true

# tests whether at least one item in a collection satisfies local conditions
check = deferrable ([ item, rest... ], context ) ->
  if item?
    target = { item, state: context.state }
    evaluate target, context.closure, ( passed ) ->
      if passed
        true
      else
        check rest, context, ( result ) -> result
  else
    false

# sequentially runs an action on all items in a collection matching conditions
process = deferrable ([ item, rest... ], context ) ->
  if item?
    target = { item, state: context.state }
    evaluate target, context.closure, ( passed ) ->
      if passed
        execute target, context.run, ->
          process rest, context, ( result ) -> result
      else
        process rest, context, ( result ) -> result
  else
    return

# Aggregator compiles collection rules (.each) down to Athena primitives
class Aggregator

  constructor: ( @athena, @selector ) ->
    @conditions = new Conditions()

  conditions: ( dictionary ) ->
    ( @conditions.register dictionary )
    @

  condition: ( specifier... ) ->
    ( @conditions.condition specifier... )
    @

  action: do ->
    ( Generic.make "Aggregator::action" )

      # expands an iterative action into a has-targets condition and engine rule
      .define [ Object ], ({ name, run, when: _when = [] }) ->
        selector = @selector

        local = @conditions.closure _when
        parent = 
          @athena.conditions
            .closure _when
            .map ( entry ) -> entry.name
        condition = "#{name}:has-targets"

        # sub-rule condition checking if any item matches local conditions
        @athena.conditions.condition {
          name: condition
          run: ( state ) ->
            select selector, state, ( collection ) ->
              check collection, 
                { state, closure: local }, 
                ( result ) -> result
        }

        # primary engine rule combining parent conditions with has-targets
        @athena.engine.rules[ name ] =
          name: name
          when: [ parent..., condition ]
          run: ( state ) ->
            select selector, state, ( collection ) ->
              context = { state, closure: local, run }
              process collection, context, ( result ) -> result

        @athena

      .define [ tuple 2 ], ([ name, run ]) ->
        @action { name, run }

      .define [ tuple 3 ], ([ name, _when, run ]) ->
        @action { name, run, when: _when }

export default Aggregator
