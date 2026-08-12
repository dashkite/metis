import Generic from "@dashkite/generic"
import { tuple, deferrable } from "./helpers.js"
import Conditions from "./conditions.js"

test = deferrable ({ item, state }, entry ) ->
  entry.predicate.call item, state

execute = deferrable ({ item, state }, run ) ->
  run.call item, state

select = deferrable ( selector, state ) ->
  selector.call state, state

evaluate = deferrable ( target, [ entry, rest... ]) ->
  if entry?
    test target, entry, ( passed ) ->
      if passed
        evaluate target, rest, ( result ) -> result
      else
        false
  else
    true

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

      .define [ Object ], ({ name, run, when: _when = [] }) ->
        selector = @selector

        local = @conditions.closure _when
        parent = 
          @athena.conditions
            .closure _when
            .map ( entry ) -> entry.name
        condition = "#{name}:has-targets"

        @athena.conditions.condition {
          name: condition
          run: ( state ) ->
            select selector, state, ( collection ) ->
              check collection, { state, closure: local }, ( result ) -> result
        }

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
