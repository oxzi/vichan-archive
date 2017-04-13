#lang racket

(provide board-url
         boards
         sql-cfg)

(define board-url "https://lainchan.org/")
(define boards (list "λ" "r" "q" "lain"))

(define sql-cfg (hash 'user "postgres"
                      'pass "postgres"
                      'db   "vichan-dump"))