#+quicklisp (ql:quickload :swank)
#-quicklisp (asdf:load-system :swank)
(swank:create-server :dont-close T)
(loop until swank::*connections* do (sleep 0.1))
(loop while swank::*connections* do (sleep 1.0))
