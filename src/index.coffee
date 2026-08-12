import { isDefined } from "@dashkite/joy"
import Generic from "@dashkite/generic"
import { tuple, hasEvaluator, isSync, isAsync, isIterable } from "./helpers.js"
import Rules from "./rules.js"
import Conditions from "./conditions.js"
import Actions from "./actions.js"
import { SyncEvaluator, AsyncEvaluator } from "./evaluators.js"
import Aggregator from "./aggregator.js"

class Athena

  @make: ( options = {} ) -> 
    instance = new @
    instance.engine = Rules.make options
    instance.conditions = new Conditions()
    instance.engine.conditions = instance.conditions
    instance

  conditions: ( dictionary ) ->
    @conditions.register dictionary
    @

  actions: ( dictionary ) ->
    Actions.register @engine, dictionary
    @

  rules: ( dictionary ) ->
    Rules.register @engine, dictionary
    @

  each: ( selector ) ->
    new Aggregator @, selector

  condition: do ->
    ( Generic.make "Athena::condition" )
      .define [ Object ], ( specifier ) ->
        @conditions.condition specifier
        if specifier.when?
          @rules [ specifier.name ]: specifier.when
        @

      .define [ tuple 2 ], ([ name, run ]) ->
        @condition { name, run }

      .define [ tuple 3 ], ([ name, conditions, run ]) ->
        @condition { name, run, when: conditions }

  action: do ->
    ( Generic.make "Athena::action" )
      .define [ Object ], ( specifier ) ->
        @actions [ specifier.name ]: specifier.run
        if specifier.when?
          @rules [ specifier.name ]: specifier.when
        @

      .define [ tuple 2 ], ([ name, run ]) ->
        @action { name, run }

      .define [ tuple 3 ], ([ name, conditions, run ]) ->
        @action { name, run, when: conditions }

  start: do ->
    ( Generic.make "Athena::start" )
      .define [ isDefined ], ( state ) ->
        ( AsyncEvaluator.make @engine, state ).start()

      .define [ isDefined, isIterable ], ( state, delegator ) ->
        ( AsyncEvaluator.make @engine, state ).start delegator
        
      .define [ isDefined, hasEvaluator ], ( state, options ) ->
        ( options.evaluator.make @engine, state ).start options.delegator

      .define [ isDefined, isSync ], ( state, options ) ->
        ( SyncEvaluator.make @engine, state ).start options.delegator

      .define [ isDefined, isAsync ], ( state, options ) ->
        ( AsyncEvaluator.make @engine, state ).start options.delegator

      .define [ isDefined, Function ], ( state, evaluator ) ->
        ( evaluator.make @engine, state ).start()

      .define [ isDefined, Function, isDefined ],
        ( state, evaluator, delegator ) ->
          ( evaluator.make @engine, state ).start delegator

  run: do ->
    ( Generic.make "Athena::run" )
      .define [ isDefined ], ( state ) ->
        ( AsyncEvaluator.make @engine, state ).run()
        
      .define [ isDefined, hasEvaluator ], ( state, options ) ->
        ( options.evaluator.make @engine, state ).run()
        
      .define [ isDefined, isSync ], ( state, options ) ->
        ( SyncEvaluator.make @engine, state ).run()

      .define [ isDefined, isAsync ], ( state, options ) ->
        ( AsyncEvaluator.make @engine, state ).run()

      .define [ isDefined, Function ], ( state, evaluator ) ->
        ( evaluator.make @engine, state ).run()

export default Athena
export {
  Rules
  Conditions
  Actions
  Athena
  Aggregator
  SyncEvaluator
  AsyncEvaluator
}