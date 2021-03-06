#lang racket
(require opencl/c
         "../atiUtils/utils.rkt"
         ffi/unsafe
         ffi/cvector
         ffi/unsafe/cvector)

(define S_LOWER_LIMIT 10.0)
(define S_UPPER_LIMIT 100.0)
(define K_LOWER_LIMIT 10.0)
(define K_UPPER_LIMIT 100.0)
(define T_LOWER_LIMIT 1.0)
(define T_UPPER_LIMIT 10.0)
(define R_LOWER_LIMIT 0.01)
(define R_UPPER_LIMIT 0.05)
(define SIGMA_LOWER_LIMIT 0.01)
(define SIGMA_UPPER_LIMIT 0.10)

(define setupTime -1)
(define totalKernelTime -1)
(define devices #f)
(define context #f)
(define commandQueue #f)
(define program #f)
(define kernel #f)
(define samples (* 256 256))
(define blockSizeX 1)
(define blockSizeY 1)
(define width 0)
(define height 0)
(define randArray #f)
(define deviceCallPrice #f)
(define devicePutPrice #f)
(define hostCallPrice #f)
(define hostPutPrice #f)
(define randBuf #f)
(define callPriceBuf #f)
(define putPriceBuf #f)

(define (setupBlackScholes)
  (set! width (sqrt samples))
  (set! height width)
  (set! randArray (malloc (* width height (ctype-sizeof _cl_float4)) 'raw))
  (for ([i (in-range (* width height 4))])
    (ptr-set! randArray _cl_float i (random)))
  (set! deviceCallPrice (malloc (* width height (ctype-sizeof _cl_float4)) 'raw))
  (memset deviceCallPrice 0 (* width height (ctype-sizeof _cl_float4)))
  (set! devicePutPrice (malloc (* width height (ctype-sizeof _cl_float4)) 'raw))
  (memset devicePutPrice 0 (* width height (ctype-sizeof _cl_float4))))


(define (setupCL)
  (set!-values (devices context commandQueue program) (init-cl "BlackScholes_Kernels.cl" #:queueProperties 'CL_QUEUE_PROFILING_ENABLE))
  (set! randBuf (clCreateBuffer context '(CL_MEM_READ_ONLY CL_MEM_USE_HOST_PTR) (* width height (ctype-sizeof _cl_float4)) randArray))
  (set! callPriceBuf (clCreateBuffer context 'CL_MEM_WRITE_ONLY (* width height (ctype-sizeof _cl_float4)) #f))
  (set! putPriceBuf (clCreateBuffer context 'CL_MEM_WRITE_ONLY (* width height (ctype-sizeof _cl_float4)) #f))
  (set! kernel (clCreateKernel program #"blackScholes"))
  (define kernelWorkGroupSize (optimum-threads kernel (cvector-ref devices 0) 256))
  (let loop ()
    (when (< (* blockSizeX blockSizeY) kernelWorkGroupSize)
      (when (<= (* 2 blockSizeX blockSizeY) kernelWorkGroupSize) (set! blockSizeX (* 2 blockSizeX)))
      (when (<= (* 2 blockSizeX blockSizeY) kernelWorkGroupSize) (set! blockSizeY (* 2 blockSizeY)))
      (loop))))

(define (runCLKernels)
  (define globalThreads (vector width height))
  (define localThreads (vector blockSizeX blockSizeY))
  (clSetKernelArg:_cl_mem kernel 0 randBuf)
  (clSetKernelArg:_cl_int kernel 1 width)
  (clSetKernelArg:_cl_mem kernel 2 callPriceBuf)
  (clSetKernelArg:_cl_mem kernel 3 putPriceBuf)
  (clEnqueueNDRangeKernel commandQueue kernel 2 globalThreads localThreads (make-vector 0))
  (clFinish commandQueue)
  (clEnqueueReadBuffer commandQueue callPriceBuf 'CL_TRUE 0 (* width height (ctype-sizeof _cl_float4)) deviceCallPrice (make-vector 0))
  (clEnqueueReadBuffer commandQueue putPriceBuf 'CL_TRUE 0 (* width height (ctype-sizeof _cl_float4)) devicePutPrice (make-vector 0)))

(define (phi X)
  (define c1 0.319381530)
  (define c2 -0.356563782)
  (define c3 1.781477937)
  (define c4 -1.821255978)
  (define c5 1.330274429)
  (define oneBySqrt2pi 0.398942280)
  (define absX (abs X))
  (define t (/ 1.0 (+ 1.0 (* 0.2316419 absX))))
  (define y (- 1.0 (* oneBySqrt2pi
                      (exp (/ (* (- X) X) 2.0))
                      t
                      (+ c1 (* t
                               (+ c2 (* t 
                                        (+ c3 (* t
                                                 (+ c4 (* t c5)))))))))))
  (if (< X 0) (- 1.0 y) y))

(define (blackScholesCPUReference)
  (set! hostCallPrice (malloc (* width height (ctype-sizeof _cl_float4)) 'raw))
  (memset hostCallPrice 0 (* width height (ctype-sizeof _cl_float4)))
  (set! hostPutPrice (malloc (* width height (ctype-sizeof _cl_float4)) 'raw))
  (memset hostPutPrice 0 (* width height (ctype-sizeof _cl_float4)))
  (for ([y (in-range (* width height 4))])
    (define val (ptr-ref randArray _cl_float y))
    (define s (+ (* S_LOWER_LIMIT val) (* S_UPPER_LIMIT (- 1.0 val))))
    (define k (+ (* K_LOWER_LIMIT val) (* K_UPPER_LIMIT (- 1.0 val))))
    (define t (+ (* T_LOWER_LIMIT val) (* T_UPPER_LIMIT (- 1.0 val))))
    (define r (+ (* R_LOWER_LIMIT val) (* R_UPPER_LIMIT (- 1.0 val))))
    (define sigma (+ (* SIGMA_LOWER_LIMIT val) (* SIGMA_UPPER_LIMIT (- 1.0 val))))
    (define sigmaSqrtT (* sigma (sqrt t)))
    (define d1 (/ (+ (log (/ s k)) 
                     (* t
                        (+ r 
                           (/ (* sigma sigma) 2))))
                  sigmaSqrtT))
    (define d2 (- d1 sigmaSqrtT))
    (define KexpMinusRT (* k (exp (* (- r) t))))
    (ptr-set! hostCallPrice _cl_float y 
              (- (* s (phi d1)) (* KexpMinusRT (phi d2))))
    (ptr-set! hostPutPrice _cl_float y
              (- (* KexpMinusRT (phi (- d2))) (* s (phi (- d1))))))
  (define result (if (compare hostCallPrice deviceCallPrice (* width height 4) 0.01)
      (compare hostPutPrice devicePutPrice (* width height 4) 0.01)
      #f))
  result)

(define (setup)
  (setupBlackScholes)
  (set! setupTime (time-real setupCL)))

(define (run)
  (set! totalKernelTime (time-real runCLKernels)))

(define (verify-results)
  (define verified (blackScholesCPUReference))
  (printf "~n~a~n" (if verified "Passed" "Failed")))

(define (print-stats)
  (define actualSamples (* width height 4))
  (printf "~nOption Samples: ~a, Setup Time: ~a, Kernel Time: ~a, Total Time: ~a, Options/sec: ~a~n"
          actualSamples 
          (real->decimal-string setupTime 3) 
          (real->decimal-string totalKernelTime 3)
          (real->decimal-string (+ setupTime totalKernelTime) 3)
          (real->decimal-string (/ actualSamples (+ setupTime totalKernelTime)))))

(define (cleanup)
  (clReleaseKernel kernel)
  (clReleaseProgram program)
  (clReleaseMemObject randBuf)
  (clReleaseMemObject callPriceBuf)
  (clReleaseMemObject putPriceBuf)
  (clReleaseCommandQueue commandQueue)
  (clReleaseContext context)
  (free randArray)
  (free deviceCallPrice)
  (free devicePutPrice)
  (free hostCallPrice)
  (free hostPutPrice))

(setup)
(run)
(verify-results)
(cleanup)
(print-stats)