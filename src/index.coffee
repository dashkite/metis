# import { negate } from "@dashkite/joy/predicate"
import * as Val from "@dashkite/joy/value"
import * as Arr from "@dashkite/joy/array"

# OOP-friendly negate
negate = ( predicate ) -> 
  ( value ) -> !( predicate.call @, value )

Rule =
  make: ({ conditions, action }) ->
    { conditions, action }

  defaults:
    equal: Val.equal
    clone: structuredClone

Rules =

  make: ( options ) ->
    { 
      Rule.defaults...
      options...
      rules: []
      conditions: {}
      actions: {}
    }

  register: ( engine, rules ) ->
    engine.rules = Arr.cat engine.rules,
      for name, conditions of rules
        Rule.make
          name: name
          conditions: conditions.map ( name ) ->
            do ({ apply } = {}) ->
              if ( name.startsWith "!" )
                name = name[1..]
                negated = true              
              if ( apply = engine.conditions[ name ])?
                apply = negate apply if negated
                { name, apply }
              else
                throw new Error "unknown condition:
                  #{ name }"
          action: do ({ apply } = {}) ->
            if ( apply = engine.actions[ name ])?
              { name, apply }
            else
              throw new Error "unknown action:
                #{ name }"
    
  run: ( engine, state ) ->
    do ({ rules, rule, saved, changed } = {}) ->
      loop
        rules = engine.rules.filter ({ conditions }) ->
          conditions.every ({ name, apply }) -> 
            result = apply.call state
            result
        saved = state
        state = engine.clone state
        for rule in rules
          yield { name: "rule", rule: rule.name }
          await rule.action.apply.call state
        changed = !( engine.equal saved, state )
        if changed
          yield { name: "change", state }
        else
          break
      yield { name: "done", state }
      state

Conditions =

  register: ( engine, conditions ) ->
    engine.conditions = { engine.conditions..., conditions... }

Actions =
  
  register: ( engine, actions ) ->
    engine.actions = { engine.actions..., actions... }

class Athena

  @make: ( options ) -> 
    Object.assign ( new @ ), 
      engine: Rules.make options

  conditions: ( dictionary ) ->
    Conditions.register @engine, dictionary

  actions: ( dictionary ) ->
    Actions.register @engine, dictionary

  rules: ( dictionary ) ->
    Rules.register @engine, dictionary

  apply: ( state, args ) ->
    if args?[0]?
      Object.assign state,
        await yield from args[0]
    yield from Rules.run @engine, state
    

export default Athena
export { Rules, Rule, Conditions, Actions, Athena }