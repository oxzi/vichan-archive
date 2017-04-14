#lang racket

(require racket/struct)

(provide (struct-out post))

; See https://github.com/vichan-devel/vichan-API/#posts-object
(struct post
  (board     ; string?                     ; Board name
   no        ; exact-nonnegative-integer?  ; Post number
   thread-no ; exact-nonnegative-integer?  ; OP's post number
   time      ; exact-nonnegative-integer?  ; Timestamp
   name      ; string?                     ; Poster's name
   com       ; string?                     ; Comment, the post itself
   existing) ; boolean?                    ; Does the post (still) exists?

  #:guard (λ (board no thread-no time name com existing type-name)
            (unless (string? board)
              (error "board must be a string"))
            (unless (exact-nonnegative-integer? no)
              (error "no must be a non-negative integer"))
            (unless (exact-nonnegative-integer? thread-no)
              (error "thread-no must be a non-negative integer"))
            (unless (exact-nonnegative-integer? time)
              (error "time must be a non-negative integer"))
            (unless (string? name)
              (error "name must be a string"))
            (unless (string? com)
              (error "com must be a string"))
            (unless (boolean? existing)
              (error "existing must be a boolean"))
            (values board no thread-no time name com existing))
  
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