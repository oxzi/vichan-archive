#lang racket

(require "config.rkt"
         "inc/data.rkt"
         "inc/database.rkt"
         "inc/dump.rkt")

; string? -> (listof number?)
; This function checks all current threads on the given board against those
; stored in the database and returns a pair of (lists of ids from new and
; changed threads) and (lists of ids from dead ones).
(define/contract (changed-threads board)
  (string? . -> . (listof (listof number?)))

  (log-debug (string-append "Checking /" board "/ for new threads"))
  (let* ([url (string-append board-url board "/threads.json")]
         [json-data    (vichan-json->hash-table url)]
         [threads-live (vichan-threads json-data)]
         
         [threads-db (db-threads-dmp board true)]

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
         [thread-new (map thread->no (filter thread-new? threads-live))]

         [thread-dead?
          (λ (thrd)
            (null? (filter (λ (t) (eq? (thread->no t) (thread->no thrd)))
                           threads-live)))]
         [thread-dead (map thread->no (filter thread-dead? threads-db))])
    (log-debug (string-append "There is/are "
                              (number->string (length thread-new))
                              " new and "
                              (number->string (length thread-dead))
                              " deleted threads on /" board "/"))
    (list thread-new thread-dead)))

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
    (when (> (length posts-del) 0)
      (log-info (string-append "There was/were "
                               (number->string (length posts-del-marked))
                               " posts deleted in " number
                               " on /" board "/")))
    (for-each db-post-upsert (append posts-new posts-del-marked))))

; string? number? -> void?
; Marks the thread as deleted (non-existing) in the database.
(define/contract (mark-thread-as-dead board no)
  (string? number? . -> . void?)
  
  (log-info (string-append "Marking thread " (number->string no)
                           " on /" board "/ as deleted."))
  (let* ([op-post (db-post board no)]
         [op-post-del (struct-copy post op-post [existing false])])
    (db-post-upsert op-post-del)))

(for-each (λ (board)
            (match (changed-threads board)
              [(list news deads)
               (for-each (λ (no) (dump-thread board no))         news)
               (for-each (λ (no) (mark-thread-as-dead board no)) deads)]))
          boards)