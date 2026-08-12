import Generic from "@dashkite/generic"
import { tuple } from "./helpers.js"
import Conditions from "./conditions.js"

class Aggregator

  constructor: ( @athena, @selector ) ->
    @conditions = new Conditions @athena.conditions

  conditions: ( dictionary ) ->
    ( @conditions.register dictionary )
    @

  condition: ( specifier... ) ->
    ( @conditions.condition specifier... )
    @

  action: do ->
    ( Generic.make "Aggregator::action" )

      .define [ Object ], ( specifier ) ->
        @athena.engine.rules[ specifier.name ] = {
          specifier...
          each: @selector
          @conditions
        }

        @athena

      .define [ tuple 2 ], ([ name, run ]) ->
        @action { name, run }

      .define [ tuple 3 ], ([ name, conditions, run ]) ->
        @action { name, run, when: conditions }

export default Aggregator
