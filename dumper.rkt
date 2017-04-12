#lang racket

(require "inc/data.rkt"
         "inc/database.rkt"
         "inc/dump.rkt")

(define board-url "https://lainchan.org/")
(define boards (list "λ" "q" "lain"))

; string? -> (list-of number?)
; This function checks all current threads on the given board against those
; stored in the database and returns a list of ids fromt new and changed ones.
(define (new-threads board)
  (let* ([url (string-append board-url board "/threads.json")]
         [json-data    (vichan-json->hash-table url)]
         [threads-live (vichan-threads json-data)]
         
         [threads-db (db-threads-dmp board)]

         [thread->no   (λ (thread) (car  thread))]
         [thread->time (λ (thread) (cadr thread))]

         ; (A -> boolean?) (list-of A) -> boolean?
         [exists (λ (fun lst) (not (boolean? (memf fun lst))))]

         ; Filter those threads which aren't in the database and
         ; those which have a newer timestamp for the last post.
         ; This may need some refactoring..
         [threads-new
          (filter (λ (tl) (not (exists (λ (td)
                                         (eq? (thread->no tl) (thread->no td)))
                                       threads-db)))
                  threads-live)]
         [threads-updated
          (filter (λ (tl) (exists (λ (td)
                                    (and
                                     (eq? (thread->no tl) (thread->no td))
                                     (> (thread->time tl) (thread->time td))))
                                  threads-db))
                  threads-live)]
         [threads-relevant (append threads-new threads-updated)])
    (map thread->no threads-relevant)))

(define (dump-thread board number)
  (let* ([url (string-append
               board-url board "/res/" (number->string number) ".json")]
         [json-data  (vichan-json->hash-table url)]
         [posts-live (vichan-thread json-data board)]

         [posts-db (db-thread board number)])
    ; TODO: check duplicates; check deleted posts; check changes
    (for-each db-post-upsert posts-live)))

(for-each (λ (board)
            (let ([threads (new-threads board)])
              (for-each (λ (no) (dump-thread board no)) threads)))
          boards)