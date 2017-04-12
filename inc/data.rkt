#lang racket

(require racket/struct)

(provide (struct-out post))

; See https://github.com/vichan-devel/vichan-API/#posts-object
(struct post
  (board     ; Board name
   no        ; Post number
   thread-no ; OP's post number
   time      ; Timestamp
   name      ; Poster's name
   com       ; Comment; the post itself
   existing) ; Does the post (still) exists?
  
  #:methods gen:custom-write
  [(define write-proc
     (make-constructor-style-printer
      (λ (obj) 'post)
      (λ (obj) (list (post-board     obj)
                     (post-no        obj)
                     (post-thread-no obj)
                     (post-time      obj)
                     (post-name      obj)
                     (post-com       obj)
                     (post-existing  obj)))))])