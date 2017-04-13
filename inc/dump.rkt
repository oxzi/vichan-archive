#lang racket

(require json
         net/http-client
         net/url
         "data.rkt")

(provide (contract-out
          [vichan-json->hash-table  (string?          . -> . jsexpr?)]
          [vichan-hash-table-error? (any/c            . -> . boolean?)]
          [vichan-threads           ((listof jsexpr?) . -> . (listof pair?))]
          [vichan-thread            (jsexpr? string?  . -> . (listof post?))]))

; bytes? -> number?
; Tries to parse the HTTP status code from a HTTP-response as a number.
; A '0' will be returned if the regexp fails.
(define (http-status-bytes->code status-bytes)
  (let* ([status-rgxp (regexp-match #rx"HTTP/[0-9.]+ ([0-9]+) .*" status-bytes)]
         [status-strng (match status-rgxp
                         [(list _ status) (bytes->string/utf-8 status)]
                         [_ "0"])])
    (string->number status-strng)))

; string? -> jsexpr?
; Tries to download the content of the given URL as a JSON and parse it.
(define (vichan-json->hash-table url)
  (let*-values
      ([(request-url) (string->url url)]
       [(status-bytes headers resp-port)
        (http-sendrecv (url-host request-url)
                       url
                       #:ssl? (string=? (url-scheme request-url) "https"))]
       [(status-code) (http-status-bytes->code status-bytes)]
       [(status-code-invalid?) (λ (code) (not (<= 200 code 399)))])
    (cond
      [(status-code-invalid? status-code)
       (hasheq 'error (string-append "Invalid status code: "
                                     (number->string status-code)))]
      [(or (not (input-port? resp-port)) (port-closed? resp-port))
       (hasheq 'error "http-sendrecv returned an invalid port")]
      [true
       (string->jsexpr (port->string resp-port))])))

; any -> boolean?
; Checks if the given parameter can be an error from vichan-json->hash-table
(define (vichan-hash-table-error? ht)
  (and (hash? ht)
       (hash-has-key? ht 'error)))

; (list-of jsexpr?) -> (listof pair?)
; This function expects the /BOARD/threads.json-response from the
; vichan-json->hash-table function and returns a list of tuples. The first
; element is the thread-no and the second element is the last modified timestamp
(define (vichan-threads json)
  (let* ([json-threads (map (λ (hs) (hash-ref hs 'threads)) json)]
         [json-single  (foldl append '() json-threads)]
         [json-pairs   (map (λ (hs) (list (hash-ref hs 'no)
                                          (hash-ref hs 'last_modified)))
                            json-single)])
    json-pairs))

; jsexpr? [string?] -> (listof post?)
; This function expects the /BOARD/res/NO.json-response from the
; vichan-json->hash-table function and returns a list of posts. The second
; parameter is the (optional) board name.
(define (vichan-thread json [board ""])
  (let* ([json-posts (hash-ref json 'posts)]
         [thread-no (hash-ref (car json-posts) 'no)]
         [hash-ref-or-else (λ (hs key [else ""])
                             (if (hash-has-key? hs key)
                                 (hash-ref hs key)
                                 else))]
         [json-post->post (λ (hs) (post board
                                        (hash-ref hs 'no)
                                        thread-no
                                        (hash-ref hs 'time)
                                        (hash-ref-or-else hs 'name)
                                        (hash-ref-or-else hs 'com)
                                        #t))])
    (map json-post->post json-posts)))