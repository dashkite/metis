# import { negate } from "@dashkite/joy/predicate"
import * as Val from "@dashkite/joy/value"
import * as Arr from "@dashkite/joy/array"
import Events from "@dashkite/events"

# OOP-friendly negate
negate = ( predicate ) -> 
  ( value ) -> !( predicate.call @, value )

Rule =
  make: ({ conditions, action }) ->
    { conditions, action }

  defaults:
    equal: Val.equal
    dump: ( state ) -> state
    clone: structuredClone

Rules =

  make: ( options ) ->
    { 
      Rule.defaults...
      options...
      rules: []
      conditions: {}
      actions: {}
      events: Events.create()
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
    await do ({ rules, rule, saved, changed } = {}) ->
      loop
        rules = engine.rules.filter ({ conditions }) ->
          conditions.every ({ name, apply }) -> 
            result = apply.call state
            result
        saved = state
        state = engine.clone state
        for rule in rules
          await rule.action.apply.call state
        changed = !( engine.equal saved, state )
        if changed
          engine.events.dispatch "change", state
        else
          break
      state

Conditions =

  register: ( engine, conditions ) ->
    engine.conditions = { engine.conditions..., conditions... }

Actions =
  
  register: ( engine, actions ) ->
    engine.actions = { engine.actions..., actions... }

# convenient class interface
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

  apply: ( state ) ->
    Rules.run @engine, state

export default Athena
export { Rules, Rule, Conditions, Actions, Athena }