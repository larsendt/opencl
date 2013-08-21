#lang racket/base
(require ffi/unsafe)

(define opencl-path
  (case (system-type)
    [(macosx)
     (build-path "/System" "Library" "Frameworks" "OpenCL.framework" "OpenCL")]
    [(windows)
     (build-path (getenv "WINDIR") "system32" "OpenCL")]
    [(unix)
     "libOpenCL"]
    [else
     (error 'opencl "This platform is not (yet) supported.")]))

(define opencl-lib (ffi-lib opencl-path))

(define-syntax define-opencl
  (syntax-rules ()
    [(_ id ty)
     (define-opencl id id ty)]
    [(_ id internal-id ty)
     (define id (get-ffi-obj 'internal-id opencl-lib ty))]))

(define (get-opencl-extension id ty)
  (define clGetExtensionFunctionAddress
    (get-ffi-obj 'clGetExtensionFunctionAddress
                 opencl-lib
                 (_fun [funcname : _string]
                       -> [funcptr : (_or-null _pointer)]
                       ->
                       (cond
                         [(not funcptr)
                          (error 'clGetExtensionFunctionAddress "~e is not supported by the OpenCL implementation" funcname)]
                         [else
                           funcptr]))))
  (cast
    (clGetExtensionFunctionAddress (symbol->string id))
    _pointer
    ty))

(define-syntax define-opencl-extension
  (syntax-rules ()
    [(_ id ty)
     (define-opencl-extension id id ty)]
    [(_ id internal-id ty)
     (define id (get-opencl-extension 'internal-id ty))]))

(provide define-opencl
         define-opencl-extension)
