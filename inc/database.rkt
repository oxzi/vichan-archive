#lang racket

(require db
         "data.rkt")

(provide db-boards
         db-threads
         db-threads-dmp
         db-thread
         db-post-upsert)

(define pgc (postgresql-connect #:user "postgres"
                                #:password "postgres"
                                #:database "vichan-dump"))

; -> (list-of pair?)
; Returns a list of pairs with board-name and amount of posts.
(define (db-boards)
  (map vector->list (query-rows pgc "SELECT * FROM boards")))

; [string?|false] -> (list-of list?)
; Returns a list of lists with board-name, thread-no, posts and the
; timestamp of the last post.
(define (db-threads [board false])
  (let ([rows
         (if (string? board)
             (query-rows pgc
                         "SELECT * FROM threads WHERE board = $1"
                         board)
             (query-rows pgc "SELECT * FROM threads"))])
    (map vector->list rows)))

; string? -> (list-of pair?)
; Returns a list of pairs with thread-no and the timestamp of the last post
; for each thread on the given board. This function is written with an analog
; return as the vichan-threads function in dump.rkt.
(define (db-threads-dmp board)
  (let ([threads (db-threads board)]
        [dump-rows (λ (t) (list (cadr t) (cadddr t)))])
    (map dump-rows threads)))

; string? number? -> (list-of post?)
; Queries the database for the thread in board with thread-no. This function
; will return a list of post-structs.
(define (db-thread board thread-no)
  (let ([rows (query-rows
               pgc
               "SELECT * FROM posts WHERE board = $1 AND thread_no = $2"
               board
               thread-no)]
        [row->post (λ (vec)
                     (call-with-values (λ () (vector->values vec)) post))])
    (map row->post rows)))

; post? -> void?
; Function to insert/update the given post-struct to the database.
; An update is based on the post number and board name.
(define (db-post-upsert post)
  (start-transaction pgc)
  (query-exec pgc
              (string-append
               "UPDATE posts SET name = $1, com = $2, existing = $3 "
               "WHERE board = $4 AND no = $5")
              (post-name     post)
              (post-com      post)
              (post-existing post)
              (post-board    post)
              (post-no       post))
  (query-exec pgc
              (string-append
               "INSERT INTO posts "
               "(board, no, thread_no, time, name, com, existing) "
               "SELECT $1, $2, $3, $4, $5, $6, $7 "
               "WHERE NOT EXISTS ( "
               "  SELECT 1 FROM posts WHERE board = $8 AND no = $9)")
              (post-board     post)
              (post-no        post)
              (post-thread-no post)
              (post-time      post)
              (post-name      post)
              (post-com       post)
              (post-existing  post)
              (post-board     post)
              (post-no        post))
  (commit-transaction pgc))