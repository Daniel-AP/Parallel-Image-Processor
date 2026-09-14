#lang swindle

(require racket/file)

(provide parse-request
    write-success)

;; Domain: Scheme command-line arguments
;; Codomain: A valid request

(define parse-request
    (lambda (arguments)
        (cond
            ((and
                (= (length arguments) 10)
                (string=? (cadddr arguments) "gaussian"))
                (list
                    (car arguments)
                    (cadr arguments)
                    (caddr arguments)
                    (list
                        'gaussian
                        (string->number (car (cddddr arguments)))
                        (string->number (cadr (cddddr arguments))))
                    (list
                        (string->number (caddr (cddddr arguments)))
                        (string->number (cadddr (cddddr arguments))))
                    (list
                        (string->number (car (cddddr (cddddr arguments))))
                        (string->number (cadr (cddddr (cddddr arguments)))))))
            ((and
                (= (length arguments) 8)
                (string=? (cadddr arguments) "grayscale"))
                (list
                    (car arguments)
                    (cadr arguments)
                    (caddr arguments)
                    (list 'grayscale)
                    (list
                        (string->number (car (cddddr arguments)))
                        (string->number (cadr (cddddr arguments))))
                    (list
                        (string->number (caddr (cddddr arguments)))
                        (string->number (cadddr (cddddr arguments))))))
            (else
                (error "Invalid Scheme request")))))

;; Domain: A status file path
;; Codomain: No return

(define write-success
    (lambda (status-path)
        (call-with-output-file
            status-path
            (lambda (output)
                (display
                    "ok"
                    output)))))
