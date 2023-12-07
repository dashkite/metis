import assert from "@dashkite/assert"
import {test, success} from "@dashkite/amen"
import print from "@dashkite/amen-console"
import { Rules, Conditions, Actions } from "../src"

rules = Rules.make

  equal: ( a, b ) ->
    a.activity == b.activity

  dump: ( state ) -> state
  
  logger: debug: ( state ) -> # console.log state


Conditions.register rules,

  "weather is good": ({ forecast }) ->
    /sunny/.test forecast

  "weather is rainy": ({ forecast }) ->
    /rain/.test forecast

Actions.register rules,
  "go for a walk": ( state ) ->
    state.activity = "walk"

  "go to a movie": ( state ) ->
    state.activity = "movie"

Rules.register rules,

  "go for a walk": [
    "weather is good"
  ]

  "go to a movie": [
    "weather is rainy"
  ]


do ->

  print await test "Metis Rules Engine", [

    test "simple rules", ->
      result = await Rules.run rules, 
        forecast: "partly sunny"

      assert.equal "walk", result.activity

  ]

  process.exit if success then 0 else 1
