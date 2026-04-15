(fn creer_ennemi [nom_p x_p y_p]
    {
        :nom nom_p
        :x x_p
        :y y_p

        :pv 100

        :deplacer (fn [self dx dy]
                (set self.x (+ self.x dx))
                (set self.y (+ self.y dy)))

        :prendre-degats (fn [self montant]
                      (set self.pv (- self.pv montant))) 

        :afficher (fn [self]
                ; spr dessine un sprite. Ici, on imagine que le sprite de base est le numéro 1
                (spr 1 self.x self.y 0))   
})