;; title:   Tower Defense
;; author:  Logan
;; desc:    Tower Defense game
;; site:    
;; license: MIT License
;; version: 0.1
;; script:  fennel
;; strict:  true


;; CONSTANTES

(local SCREEN-W 240)
(local SCREEN-H 136)
(local TILE-SIZE 8)

;; ÉTAT DU JEU

(var state :menu)
(var tick 0)

;; DRAW — écrans

(fn draw-menu []
  (print "TOWER DEFENSE" 75 40 12 true 2)
  (print "Press Z to Start" 72 70 15)
  (print "by Logan" 88 90 13))

(fn draw-gameover []
  (print "GAME OVER" 80 50 2 true 2)
  (print "Press Z to Retry" 68 90 12))

(fn draw-victory []
  (print "VICTORY!" 82 50 6 true 2)
  (print "All waves cleared!" 68 75 15)
  (print "Press Z to Replay" 66 90 12))

;; INIT

(fn init-game []
  (set tick 0)
  (set state :gameover));; Change to :playing when game logic is implemented

;; BOUCLE PRINCIPALE

(fn _G.TIC []
  (set tick (+ tick 1))

  (match state
    :menu     (do
                (cls 0)
                (draw-menu)
                (when (btnp 4) (init-game)))

    :playing  (do
                (cls 0)
                (print "Game is running..." 70 60 15)
                (print (.. "Tick: " tick) 90 75 13))

    :gameover (do
                (cls 0)
                (draw-gameover)
                (when (btnp 4) (init-game)))

    :victory  (do
                (cls 0)
                (draw-victory)
                (when (btnp 4) (init-game)))))