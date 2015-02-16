;;; -*- mode: gauche -*-

(define-module pl0.lexer
  (use text.parse :only (skip-while next-token-of))
  (use srfi-13 :only (string-ci=))
  (export pl0-tokenize))

(select-module pl0.lexer)

(define entry-table
  '(("odd"   . odd)
    ("const" . const)
    ("var"   . var)
    ("procedure" . procedure)
    ("begin" . begin)
    ("end"   . end)
    ("if"    . if)
    ("then"  . then)
    ("while" . while)
    ("do"    . do)
    ("call"  . call)
    ("writeln" . writeln)))

(define skip-white-space (pa$ skip-while #[\s]))

(define (lex port)
  (skip-white-space port)
  (let1 ch (peek-char port)
    (case ch
      ((#\= #\+ #\- #\* #\/) (read-char port) (string->symbol (string ch)))
      ((#\#) (read-char port) 'not)
      ((#\;) (read-char port) 'separator)
      ((#\,) (read-char port) 'comma)
      ((#\() (read-char port) 'reft-paren)
      ((#\)) (read-char port) 'right-paren)
      ((#\.) (read-char port) 'period)
      ((#\:)
       (read-char port)
       (let1 nch (read-char port)
         (if (eqv? nch #\=) ':= (error "Invalid character" nch))))
      ((#\< #\>)
       (read-char port)
       (let1 nch (peek-char port)
         (cond ((eqv? nch #\=)
                (read-char port)
                (case ch ((#\<) '<=) ((#\>) '>=)))
               (else (case ch ((#\<) '<) ((#\>) '>))))))
      (else
       (cond ((char-set-contains? #[0-9] ch)
              (string->number (next-token-of #[0-9] port)))
             ((char-set-contains? #[a-zA-Z] ch)
              (let1 ident (next-token-of #[a-zA-Z] port)
                (assoc-ref entry-table ident ident string-ci=)))
             (else "Invalid character" ch))))))

(define (pl0-tokenize port)
  (let loop ()
    (let ((token (lex port)))
      (if (eqv? token 'period)
          (list token)
          (lcons token (loop))))))