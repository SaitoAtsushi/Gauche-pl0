#!/usr/bin/env gosh
;;; -*- mode: gauche -*-

(use gauche.test)

(test-start "pl0")
(use pl0)
(test-module 'pl0)

(test* "gcd" "12\n"
       (with-output-to-string
         (lambda()
#!pl0
CONST m = 7, n = 85;
VAR  x, y, z;

PROCEDURE gcd;
VAR f, g;
BEGIN
  f := x; g := y;
  WHILE f # g DO BEGIN
    IF f < g THEN g := g - f;
    IF g < f THEN f := f - g
  END;
  z := f
END;

BEGIN
  x := 84;
  y := 36;
  CALL gcd;
  WRITELN z
END.
)))

(test-end :exit-on-failure #t)
