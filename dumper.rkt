#lang racket

(require "config.rkt"
         "inc/data.rkt"
         "inc/database.rkt"
         "inc/dump.rkt")

; string? -> (listof number?)
; This function checks all current threads on the given board against those
; stored in the database and returns a list of ids fromt new and changed ones.
(define/contract (new-threads board)
  (string? . -> . (listof number?))

  (log-debug (string-append "Checking /" board "/ for new threads"))
  (let* ([url (string-append board-url board "/threads.json")]
         [json-data    (vichan-json->hash-table url)]
         [threads-live (vichan-threads json-data)]
         
         [threads-db (db-threads-dmp board)]

         [thread->no   (λ (thread) (car  thread))]
         [thread->time (λ (thread) (cadr thread))]

         [thread-new?
          (λ (thrd)
            (let* ([no    (thread->no   thrd)]
                   [time  (thread->time thrd)]
                   [in-db (memf (λ (t) (eq? (thread->no t) no)) threads-db)])
              (if (boolean? in-db)
                  true
                  (> time (thread->time (car in-db))))))]
         [thread-new (map thread->no (filter thread-new? threads-live))])
    (log-debug (string-append "There are "
                              (number->string (length thread-new))
                              " new threads on /" board "/"))
    thread-new))

; string? number? -> void?
; Sync this thread with the database.
(define/contract (dump-thread board number)
  (string? number? . -> . void?)
  
  (log-debug (string-append "Starting to dump thread "
                            (number->string number) " on /" board "/"))
  (let* ([url (string-append
               board-url board "/res/" (number->string number) ".json")]
         [json-data  (vichan-json->hash-table url)]
         [posts-live (vichan-thread json-data board)]

         [posts-db (filter post-existing (db-thread board number))]

         [post-not-in-set?
          (λ (pst set) (null? (filter
                               (λ (p) (eq? (post-no p) (post-no pst)))
                               set)))]
         [posts-new (filter (λ (x) (post-not-in-set? x posts-db)) posts-live)]
         [posts-del (filter (λ (x) (post-not-in-set? x posts-live)) posts-db)]
         [posts-del-marked
          (map (λ (pst) (struct-copy post pst [existing false])) posts-del)])
    (log-info (string-append "There is/are " (number->string (length posts-new))
                             " new posts in " (number->string number)
                             " on /" board "/"))
    (and (> (length posts-del) 0)
         (log-warning (string-append "There was/were "
                                     (number->string (length posts-del-marked))
                                     " posts deleted in " number
                                     " on /" board "/")))
    (for-each db-post-upsert (append posts-new posts-del-marked))))


(for-each (λ (board)
            (let ([threads (new-threads board)])
              (for-each (λ (no) (dump-thread board no)) threads)))
          boards)