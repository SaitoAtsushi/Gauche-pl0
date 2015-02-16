;;; -*- mode: gauche -*-

(define-module pl0.parser
  (use parser.peg)
  (use pl0.lexer)
  (export pl0-parse <json-parse-error>))

(select-module pl0.parser)

(define-condition-type <pl0-parse-error> <error> #f
  (position)
  (objects))

(define ($/ parser . parsers)
  (if (null? parsers)
      parser
      ($or ($try parser) (apply $/ parsers))))

(define ($eq sym :optional (default sym))
  (lambda(vs)
    (if (eq? (car vs) sym)
        (return-result default (cdr vs))
        (return-failure/expect sym vs))))

(define %ident
  (lambda(vs)
    (let1 ident (car vs)
      (if (string? ident)
          (return-result (string->symbol ident) (cdr vs))
          (return-failure/expect "<identifier>" vs)))))

(define %number
  (lambda(vs)
    (let1 ident (car vs)
      (if (number? ident)
          (return-result ident (cdr vs))
          (return-failure/expect "<number>" vs)))))

(define %term
  ($lazy
   ($/ ($do (factor1 %factor)
            (op ($or ($eq '*) ($eq '/)))
            (factor2 %factor)
            ($return (list (case op ((/) 'div) ((*) '*)) factor1 factor2)))
       %factor)))

(define %sign
  ($or ($eq '+) ($eq '-)))

(define %expression
  ($/ ($do (sign1 ($optional %sign '+))
           (term1 %term)
           (sign2 %sign)
           (term2 %term)
           ($return
            (case sign1
              ((+) (list sign2 term1 term2))
              (else (list sign2 (list sign1 term1) term2)))))
      ($do (sign1 ($optional %sign '+)) (term %term)
           ($return (case sign1 ((+) term) (else (list sign1 term)))))))

(define %factor
  ($/ %ident
      %number
      ($between ($eq 'left-paren) %expression ($eq 'right-paren))))

(define %compare-operator
  ($/ ($eq '<=) ($eq '>=) ($eq '=) ($eq 'not) ($eq '<) ($eq '>)))

(define %condition
  ($/
   ($do (($eq 'odd)) (expr %expression)
        ($return `(odd? ,expr)))
   ($do (expr1 %expression) (op %compare-operator) (expr2 %expression)
        ($return (if (eq? op 'not)
                     `(not (= ,expr1 ,expr2))
                     `(,op ,expr1 ,expr2))))))

(define %statement
  ($lazy
   ($/ %if-statement
       %while-statement
       %statements
       %call-statement
       %writeln-statement
       %assignment)))

(define %assignment
  ($do (ident %ident) (($eq ':=)) (expr %expression)
       ($return `(set! ,ident ,expr))))

(define %separator ($eq 'separator))

(define %comma ($eq 'comma))

(define %statements
  ($do (($eq 'begin)) (statements ($sep-by %statement %separator)) (($eq 'end))
       ($return `(begin ,@statements))))

(define %if-statement
  ($do (($eq 'if)) (condition %condition) (($eq 'then)) (statement %statement)
       ($return `(when ,condition ,statement))))

(define %while-statement
  ($do (($eq 'while)) (condition %condition) (($eq 'do)) (statement %statement)
       ($return `(do ()((not ,condition)) ,statement))))

(define %call-statement
  ($do (($eq 'call)) (ident %ident)
       ($return `(,ident))))

(define %writeln-statement
  ($do (($eq 'writeln)) (expr %expression)
       ($return `(print ,expr))))

(define %const-declare
  ($between ($eq 'const)
            ($sep-by ($do (var %ident) (($eq '=)) (num %number)
                          ($return (list var num)))
                     %comma)
            %separator))

(define %var-declare
  ($between ($eq 'var) ($sep-by %ident %comma) %separator))

(define (duplicate-check lst)
  (if (null? lst)
      #f
      (or (find (pa$ eqv? (car lst)) (cdr lst))
          (duplicate-check (cdr lst)))))

(define %block
  ($do (const ($optional %const-declare '()))
       (var ($optional %var-declare '()))
       (procs ($many %procedure-define))
       (statement %statement)
       (if (or (duplicate-check (map car const)) (duplicate-check var))
           ($fail "duplicate variable")
           ($return
            `(let (,@const ,@(map (lambda(x)(list x #f)) var))
               ,@procs
               ,statement)))))

(define %procedure-define
  ($do (($eq 'procedure))
       (ident %ident)
       %separator
       (block %block)
       %separator
       ($return `(define (,ident) ,block))))

(define %program
  ($do
   (block %block)
   (($eq 'period))
   ($return block)))

(define (pl0-parse port)
  (guard (e ((<parse-error> e)
             (error <pl0-parse-error>
                    :position (~ e 'position) :objects (~ e 'objects)
                    :message (~ e 'message))))
    (values-ref
     (peg-run-parser %program (pl0-tokenize port))
     0)))
