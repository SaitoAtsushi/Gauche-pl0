;;; -*- mode: gauche -*-

(define-module pl0)

(autoload pl0.parser pl0-parse)

(select-module pl0)

(define-reader-directive 'pl0
  (^(sym port ctx)
    (pl0-parse port)))
