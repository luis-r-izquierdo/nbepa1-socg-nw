extensions [nw]

globals [
  initial-distribution
  n-of-strategies
  n-of-players
  payoffs
  strategy-numbers

  n-of-links
  connected-players
]

breed [players player]

players-own [
  strategy
  next-strategy
  my-nbrs
]

;;;;;;;;;;;;;
;;; SETUP ;;;
;;;;;;;;;;;;;

to startup
  clear-all
  setup-variables
  build-initial-network
  setup-players
  setup-graph
  reset-ticks
  update-graph
end

to setup-variables
  set initial-distribution read-from-string n-of-players-for-each-strategy
  set n-of-players sum initial-distribution
  set n-of-strategies length initial-distribution

  set payoffs n-values n-of-strategies [[i] -> insert-item i n-values (n-of-strategies - 1) [0] (i + 1)]
  print-payoffs
  set strategy-numbers (range 1 (n-of-strategies + 1))
end

to print-payoffs
  clear-output
  output-print "Payoff matrix: "
  output-print put-sublists-in-different-lines (word payoffs)
end

to setup-players
  ;; here we have to make sure that strategies are assigned
  ;; independently of the who number of the agents
  let cum-list [0]
    ;; cum-list first value is 0 and is (n-of-strategies + 1) items long
  foreach initial-distribution [? -> set cum-list lput (? + last cum-list) cum-list]

  let players-list shuffle sort players
  let i 1
  (foreach (but-last cum-list) (but-first cum-list) [ [n1 n2] ->
    let l sublist players-list n1 n2
    ask turtle-set l [
      set strategy i
      set next-strategy strategy
      update-color
    ]
    set i (i + 1)
  ])
end

to setup-graph
  set-current-plot "Strategy Distribution"
  foreach strategy-numbers [ i ->
    create-temporary-plot-pen (word i)
    set-plot-pen-mode 1
    set-plot-pen-color 35 + 50 * i
   ]
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; NETWORK CONSTRUCTION ;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to build-initial-network
  set-default-shape players "circle"
  run (word "build-" network-model "-network")
  ask players [set my-nbrs link-neighbors]
  ask players [ fd 3 ]
  set connected-players players with [any? link-neighbors]
  ask connected-players [ fd 12 ]
  set n-of-links count links
end


to build-Erdos-Reny-network
  nw:generate-random players links n-of-players prob-link
end

to build-small-world-network
 nw:generate-watts-strogatz players links n-of-players (avg-degree-small-world / 2) prob-rewiring
end

to build-preferential-attachment-network
  nw:generate-preferential-attachment players links n-of-players 1
end

to build-ring-network
  nw:generate-ring players links n-of-players
end

to build-star-network
  nw:generate-star players links n-of-players
end

to build-grid-4-nbrs-network
  let players-per-line (ceiling sqrt n-of-players)
  nw:generate-lattice-2d players links players-per-line players-per-line false
  ask n-of (count players - n-of-players) players [die]
end

;;;;;;;;;;
;;; GO ;;;
;;;;;;;;;;

to go

  if any? connected-players [

  (ifelse

    updating = "synchronous"
    [
      ask connected-players [update-next-strategy]
      ask connected-players [set strategy next-strategy]
    ]

    updating = "asynch random independent"
    [
      repeat n-of-players [
        ask one-of connected-players [
          update-next-strategy
          set strategy next-strategy
        ]
      ]
    ]

    updating = "asynch random order"
    [
      ask connected-players [
        update-next-strategy
        set strategy next-strategy
      ]
    ]
  )

  ]

  tick

  update-graph
  ask connected-players [update-color]
end

;;;;;;;;;;;;;;;;
;;; Revision ;;;
;;;;;;;;;;;;;;;;

to update-next-strategy
  ifelse (random-float 1 < noise)
    [ set next-strategy (one-of strategy-numbers) ]
    [ ;; BEP test-all, uniform-if-tie
      let payoffs-for-each-strategy map [s -> payoff-for-one-trial s ] strategy-numbers
      set next-strategy 1 + one-of max-positions payoffs-for-each-strategy
    ]
end

to-report payoff-for-one-trial [s]
  report item ([strategy] of one-of my-nbrs - 1) (item (s - 1) payoffs)
end

;;;;;;;;;;;;;;
;;; Graphs ;;;
;;;;;;;;;;;;;;

to update-graph
  let strategy-frequencies map [n -> count players with [strategy = n] / n-of-players] strategy-numbers

  set-current-plot "Strategy Distribution"
  let bar 1
  foreach strategy-numbers [ n ->
    set-current-plot-pen (word n)
    plotxy ticks bar
    set bar (bar - (item (n - 1) strategy-frequencies))
  ]
  set-plot-y-range 0 1
end

to update-color
  set color 35 + 50 * strategy
end

;;;;;;;;;;;;;;
;;; Layout ;;;
;;;;;;;;;;;;;;

;; the code in the following 3 procedures has been borrowed and slightly adapted from
;; models in the NetLogo models library, so the credit should go to Uri Wilenski and his team

to relax-network
  ;; the number 3 here is arbitrary; more repetitions slows down the
  ;; model, but too few gives poor layouts
  repeat 3 [
    ;; the more players we have to fit into the same amount of space,
    ;; the smaller the inputs to layout-spring we'll need to use
    let factor sqrt count players
    ;; numbers here are arbitrarily chosen for pleasing appearance
    layout-spring (players with [any? link-neighbors]) links (1 / factor) (7 / factor) (3 / factor)
    display  ;; for smooth animation
  ]
  ;; don't bump the edges of the world
  let x-offset max [xcor] of players + min [xcor] of players
  let y-offset max [ycor] of players + min [ycor] of players
  ;; big jumps look funny, so only adjust a little each time
  set x-offset limit-magnitude x-offset 0.1
  set y-offset limit-magnitude y-offset 0.1
  ask players [ setxy (xcor - x-offset / 2) (ycor - y-offset / 2) ]
end

to-report limit-magnitude [number limit]
  if number > limit [ report limit ]
  if number < (- limit) [ report (- limit) ]
  report number
end

to drag-and-drop
  if mouse-down? [
    let candidate min-one-of players [distancexy mouse-xcor mouse-ycor]
    if [distancexy mouse-xcor mouse-ycor] of candidate < 1 [
      ;; The watch primitive puts a "halo" around the watched turtle.
      watch candidate
      while [mouse-down?] [
        ;; If we don't force the view to update, the user won't
        ;; be able to see the turtle moving around.
        display
        ;; The subject primitive reports the turtle being watched.
        ask subject [ setxy mouse-xcor mouse-ycor ]
      ]
      ;; Undoes the effects of watch
      reset-perspective
    ]
  ]
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Supporting procedures ;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to-report max-positions [numbers]
  let biggest max numbers
  report filter [ [n] -> item n numbers = biggest] (range (length numbers))
end

to-report put-sublists-in-different-lines [s]
  let open-bracket-pos position "[" s
  set s substring s (open-bracket-pos + 1) (length s)
  let close-bracket-pos -1

  let new-s "["

  set open-bracket-pos position "[" s
  while [open-bracket-pos != false] [
    set close-bracket-pos position "]" s
    set new-s (word new-s (substring s open-bracket-pos (close-bracket-pos + 1)) "\n ")
    set s substring s (close-bracket-pos + 1) (length s)
    set open-bracket-pos position "[" s
  ]
  report (word substring new-s 0 (length new-s - 2) "]")
end
@#$#@#$#@
GRAPHICS-WINDOW
764
158
1110
505
-1
-1
10.242424242424242
1
10
1
1
1
0
0
0
1
-16
16
-16
16
0
0
1
ticks
30.0

SLIDER
24
229
249
262
noise
noise
0
0.1
0.01
0.001
1
NIL
HORIZONTAL

PLOT
259
10
755
505
Strategy Distribution
NIL
NIL
0.0
10.0
0.0
10.0
true
true
"" ""
PENS

BUTTON
25
10
111
43
setup
startup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
119
10
251
43
NIL
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
0

BUTTON
24
59
153
92
go once
go
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
0

MONITOR
159
48
251
93
NIL
ticks
17
1
11

OUTPUT
23
279
249
489
14

CHOOSER
24
179
250
224
updating
updating
"synchronous" "asynch random independent" "asynch random order"
1

INPUTBOX
23
115
250
175
n-of-players-for-each-strategy
[90 10 0 0 0 0 0 0 0 0]
1
0
String (reporter)

CHOOSER
763
10
977
55
network-model
network-model
"Erdos-Reny" "small-world" "preferential-attachment" "ring" "star" "grid-4-nbrs"
2

SLIDER
1075
10
1188
43
prob-link
prob-link
0
1
0.02
0.01
1
NIL
HORIZONTAL

SLIDER
987
81
1191
114
avg-degree-small-world
avg-degree-small-world
0
10
2.0
2
1
NIL
HORIZONTAL

SLIDER
987
118
1190
151
prob-rewiring
prob-rewiring
0
1
0.1
0.01
1
NIL
HORIZONTAL

BUTTON
765
80
892
113
NIL
relax-network
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
765
117
892
150
NIL
drag-and-drop
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

MONITOR
899
59
976
104
NIL
n-of-links
0
1
11

MONITOR
898
107
979
152
avg degree
mean [count my-nbrs] of players
2
1
11

TEXTBOX
999
12
1070
40
For \nErdos-Reny
11
0.0
1

TEXTBOX
1041
61
1191
79
For small world
11
0.0
1

@#$#@#$#@
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.2.1
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
