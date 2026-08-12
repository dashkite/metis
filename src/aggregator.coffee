import Generic from "@dashkite/generic"
import { tuple, deferrable } from "./helpers.js"
import Conditions from "./conditions.js"

test = deferrable ({ item, state }, entry ) ->
  entry.predicate.call item, state

execute = deferrable ({ item, state }, action ) ->
  action.call item, state

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
        execute target, context.action, ->
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

      .define [ Object ], ({ name, run: action, when: conditions = [] }) ->
        selector = @selector

        local = @conditions.closure conditions
        parent = @athena.conditions.closure conditions
        names = parent.map ( entry ) -> entry.name

        rules = [ names... ]

        target = "#{name}:has-targets"
        @athena.conditions.condition {
          name: target
          run: ( state ) ->
            select selector, state, ( collection ) ->
              check collection, { state, closure: local }, ( result ) -> result
        }
        rules.push target

        @athena.engine.rules[ name ] =
          name: name
          when: rules
          run: ( state ) ->
            select selector, state, ( collection ) ->
              context = { state, closure: local, action }
              process collection, context, ( result ) -> result

        @athena

      .define [ tuple 2 ], ([ name, run ]) ->
        @action { name, run }

      .define [ tuple 3 ], ([ name, conditions, run ]) ->
        @action { name, run, when: conditions }

export default Aggregator
