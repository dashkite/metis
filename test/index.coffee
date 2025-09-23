import assert from "@dashkite/assert"
import {test, success} from "@dashkite/amen"
import print from "@dashkite/amen-console"
import Athena from "../src"

rules = Athena.make

  equal: ( a, b ) ->
    a.activity == b.activity

rules
  
  .condition [
    "weather is good"
    -> /sunny/.test @forecast
  ]

  .condition [
    "weather is rainy"
    -> /rain/.test @forecast
  ]

  .action [
    "go for a walk"
    [ "weather is good" ]
    -> @activity = "walk"
  ]

  .action [
    "go to a movie"
    [ "weather is rainy" ]
    -> @activity = "movie"
  ]

do ->


  print await test "Athena Rules Engine", [

    test "simple rules", ->
      result = yield from rules.apply forecast: "partly sunny"
      assert.equal "walk", result.activity
      await return

  ]

  process.exit if success then 0 else 1
