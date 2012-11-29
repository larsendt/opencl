#lang racket
(require opencl/c
         "../utils/utils.rkt"
         ffi/cvector
         ffi/unsafe/cvector
         ffi/unsafe
         racket/runtime-path)

(define (dotProductHost data1 data2 result numElements)
  (for ([i (in-range numElements)])
    (ptr-set! result _cl_float i 0.0)
    (for ([k (in-range 4)])
      (define j (+ k (* i 4)))
      (ptr-set! result _cl_float i (+ (ptr-ref result _cl_float i)
                                      (* (ptr-ref data1 _cl_float j)
                                         (ptr-ref data2 _cl_float j)))))))

(define event #f)
(define iNumElements 1277944)    ;Length of float arrays to process (odd # for illustration)
(define-runtime-path cSourceFile "DotProduct.cl")

(display "Starting...\n\n")
(printf "# of float elements per Array \t= ~a~n" iNumElements)

;set and log Global and Local work size dimensions
(define szLocalWorkSize 128)
(define szGlobalWorkSize (roundUp szLocalWorkSize iNumElements))  ; rounded up to the nearest multiple of the LocalWorkSize
(printf "Global Work Size \t\t= ~a~nLocal Work Size \t\t= ~a~n# of Work Groups \t\t= ~a~n~n"
        szGlobalWorkSize szLocalWorkSize (/ szGlobalWorkSize szLocalWorkSize))

(display "Allocate and Init Host Mem...\n")

(define srcA (malloc _cl_float4 szGlobalWorkSize 'raw))
(define srcB (malloc _cl_float4 szGlobalWorkSize 'raw))
(define dst (malloc _cl_float szGlobalWorkSize 'raw))
(define Golden (malloc _cl_float iNumElements 'raw))
(fillArray srcA (* 4 iNumElements))
(fillArray srcB (* 4 iNumElements))

;get platform
(define platform (cvector-ref (clGetPlatformIDs:vector) 0))

;get gpu
(define devices (clGetDeviceIDs:vector platform 'CL_DEVICE_TYPE_GPU))

;create context
(define context (clCreateContext (cvector->vector devices)))

;create command queue
(display "clCreateCommandQueue...\n")
(define commandQueue (clCreateCommandQueue context (cvector-ref devices 0) '()))

;Allocate the OpenCL buffer memory objects for source and result on the device GMEM
(display "clCreateBuffer...\n")
(define cmDevSrcA (clCreateBuffer context 'CL_MEM_READ_ONLY (* (ctype-sizeof _cl_float4) szGlobalWorkSize) #f))
(define cmDevSrcB (clCreateBuffer context 'CL_MEM_READ_ONLY (* (ctype-sizeof _cl_float4) szGlobalWorkSize) #f))
(define cmDevDst (clCreateBuffer context 'CL_MEM_WRITE_ONLY (* (ctype-sizeof _cl_float) szGlobalWorkSize) #f))

;Set up program
(printf "oclLoadProgSource (~a)...~n" cSourceFile)
(define sourceBytes (file->bytes cSourceFile))
(display "clCreateProgramWithSource...\n")
(define program (clCreateProgramWithSource context (make-vector 1 sourceBytes)))
(display "clBuildProgram...\n")
(clBuildProgram program (make-vector 0) (make-bytes 0))

;Set up kernal
(display "clCreateKernel (DotProduct)...\n")
(define kernel (clCreateKernel program #"DotProduct"))
(display "clSetKernelArg 0 - 3...\n\n")
(clSetKernelArg:_cl_mem kernel 0 cmDevSrcA)
(clSetKernelArg:_cl_mem kernel 1 cmDevSrcB)
(clSetKernelArg:_cl_mem kernel 2 cmDevDst)
(clSetKernelArg:_cl_int kernel 3 iNumElements)

;Asynchronous write of data to GPU
(display "clEnqueueWriteBuffer (SrcA and SrcB)...\n")
(set! event (clEnqueueWriteBuffer commandQueue cmDevSrcA 'CL_FALSE 0 (* (ctype-sizeof _cl_float4) szGlobalWorkSize) srcA (make-vector 0)))
(set! event (clEnqueueWriteBuffer commandQueue cmDevSrcB 'CL_FALSE 0 (* (ctype-sizeof _cl_float4) szGlobalWorkSize) srcB (make-vector 0)))

;Launch Kernel
(display "clEnqueueNDRangeKernel (VectorAdd)...\n")
(set! event (clEnqueueNDRangeKernel commandQueue kernel 1 (make-vector 1 szGlobalWorkSize) (make-vector 1 szLocalWorkSize) (make-vector 0)))

;Synchronous/blocking read of results, and check accumulated errors
(display "clEnqueueReadBuffer (Dst)...\n\n")
(set! event (clEnqueueReadBuffer commandQueue cmDevDst 'CL_TRUE 0 (* (ctype-sizeof _cl_float) szGlobalWorkSize) dst (make-vector 0)))

;Compute and compare results for golden-host and report errors and pass/fail
(display "Comparing against Host/C++ computation...\n\n")
(dotProductHost srcA srcB Golden iNumElements)
(if (compareArrays dst Golden iNumElements .1)
    (display "Passed\n\n")
    (display "Failed\n\n"))

;Cleanup
(display "Starting Cleanup...\n\n")
(when kernel (clReleaseKernel kernel))
(when program (clReleaseProgram program))
(when commandQueue (clReleaseCommandQueue commandQueue))
(when context (clReleaseContext context))
(when cmDevSrcA (clReleaseMemObject cmDevSrcA))
(when cmDevSrcB (clReleaseMemObject cmDevSrcB))
(when cmDevDst (clReleaseMemObject cmDevDst))

(free srcA)
(free srcB)
(free dst)
(free Golden)

(display "oclVectorAdd Exiting...\n")