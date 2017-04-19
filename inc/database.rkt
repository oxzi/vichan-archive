#lang racket

(require db
         "../config.rkt"
         "data.rkt")

(provide (contract-out
          [db-boards      (                       ->   (listof pair?))]
          [db-threads     ((or/c string? false) . -> . (listof list?))]
          [db-threads-dmp (string? boolean?     . -> . (listof pair?))]
          [db-thread      (string? number?      . -> . (listof post?))]
          [db-post        (string? number?      . -> . (or/c post? false))]
          [db-post-upsert (post?                . -> . void?)]))

(define pgc (postgresql-connect #:user     (hash-ref sql-cfg 'user)
                                #:password (hash-ref sql-cfg 'pass)
                                #:database (hash-ref sql-cfg 'db)))

; -> (list-of pair?)
; Returns a list of pairs with board-name and amount of posts.
(define (db-boards)
  (map vector->list (query-rows pgc "SELECT * FROM boards")))

; [string?|false] -> (list-of list?)
; Returns a list of lists with board-name, thread-no, posts, the timestamp
; of the last post and a flag if the thread still exists.
(define (db-threads [board false])
  (let ([rows
         (if (string? board)
             (query-rows pgc
                         "SELECT * FROM threads WHERE board = $1"
                         board)
             (query-rows pgc "SELECT * FROM threads"))])
    (map vector->list rows)))

; string? [boolean?] -> (list-of pair?)
; Returns a list of pairs with thread-no and the timestamp of the last post
; for each thread on the given board. This function is written with an analog
; return as the vichan-threads function in dump.rkt. The second, optional
; parameter filters dead threads.
(define (db-threads-dmp board [existing-only false])
  (let ([threads (db-threads board)]
        [filter-existing (λ (t) (if existing-only
                                    (fifth t)
                                    true))]
        [dump-rows (λ (t) (list (cadr t) (cadddr t)))])
    (map dump-rows (filter filter-existing threads))))

; vector? -> post?
; Transforms a vector representing a row of the posts-table into a post.
(define/contract (row->post vec)
  (vector? . -> . post?)
  (call-with-values (λ () (vector->values vec)) post))

; string? number? -> (list-of post?)
; Queries the database for the thread in board with thread-no. This function
; will return a list of posts.
(define (db-thread board thread-no)
  (let* ([rows (query-rows
                pgc
                "SELECT * FROM posts WHERE board = $1 AND thread_no = $2"
                board
                thread-no)]
         [posts (map row->post rows)])
    (sort posts (λ (p1 p2) (< (post-no p1) (post-no p2))))))

; string? number? -> post?|false
; Returns the requested post from the database or false if it's not existing.
(define (db-post board no)
  (let ([rows (query-rows
               pgc
               "SELECT * FROM posts WHERE board = $1 AND no = $2"
               board
               no)])
    (if (null? rows)
        false
        (row->post (car rows)))))

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