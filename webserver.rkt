#lang racket

(require racket/date
         web-server/servlet
         web-server/servlet-env
         "inc/data.rkt"
         "inc/database.rkt")

(define (main-request req)
  (let ([boards (sort (db-boards) (λ (a b) (> (cadr a) (cadr b))))]
        [board->xexpr (λ (board)
                        `(tr (td
                              (a ((href
                                   ,(string-append "/threads/" (car board))))
                                 ,(car board)))
                             (td ,(number->string (cadr board)))))])
  (response/xexpr
   `(html (head (title "vichan-mirror"))
          (body (h1 "Vichan Mirror")
                (table
                   (tr (th "Board") (th "Posts"))
                   ,@(map board->xexpr boards)))))))

(define (thread-list-request req board)
  (let* ([thread-nos (map second (db-threads board))]
         [thread-url (λ (no) (app-url thread-request board no))]
         [thread-no->xexpr (λ (no)
                            `(li (a ((href ,(thread-url no)))
                                    ,(number->string no))))])
    (response/xexpr
     `(html (head (title "Posts in " ,board))
            (body (h1 "Posts in " ,board)
                  (ul ,@(map thread-no->xexpr thread-nos)))))))

(define (thread-request req board thread-no)
  (let ([posts (db-thread board thread-no)]
        [post->xexpr (λ (post)
                       `(p
                         (b ,(number->string (post-no post)))
                         ,(post-name post)
                         ", "
                         ,(date->string (seconds->date (post-time post)))
                         (br)
                         (i ,(post-com post))
                         (br) (br)))]
        [page-title (string-append "/" board "/, " (number->string thread-no))])
    (response/xexpr
     `(html (head (title ,page-title))
            (body (h1 ,page-title)
                  ,@(map post->xexpr posts))))))

(define-values (app-dispatcher app-url)
  (dispatch-rules
   [("") main-request]
   [("threads" (string-arg)) thread-list-request]
   [("thread" (string-arg) (integer-arg)) thread-request]))

(serve/servlet app-dispatcher
               #:servlet-regexp #rx""
               #:command-line? true)