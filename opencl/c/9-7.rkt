#lang at-exp racket/base

(require ffi/unsafe
         ffi/unsafe/cvector
         (except-in racket/contract ->)
         (prefix-in c: racket/contract)
         scribble/srcdoc
         sgl/gl
         "include/cl.rkt"
         "lib.rkt"
         "syntax.rkt"
         "types.rkt")

(require/doc racket/base
             scribble/manual
             (for-label "types.rkt"))

#|
(define-opencl clGetExtensionFunctionAddress
  (_fun [funcname : _string]
        -> [funcptr : (_or-null _pointer)]
        ->
        (cond
          [(not funcptr)
           (error 'clGetExtensionFunctionAddress "~e is not supported by the OpenCL implementation" funcname)]
          [else
            funcptr])))

; Since this is an opencl extension function, we'll have to
; do things a little differently. The pointer to the function
; can be obtained with eclGetExtensionFunctionAddress
(provide clGetGLContextInfoKHR:length
         clGetGLContextInfoKHR:generic)
(define (clGetGLContextInfoKHR:length properties
                                      param_name)
  (define actual-function
    (cast (clGetExtensionFunctionAddress "clGetGLContextInfoKHR")
          _pointer
          (_fun [properties : (_vector i _cl_context_properties)]
                [param_name : _cl_gl_context_info]
                [param_value_size : _size_t]
                [param_value : (_vector o _cl_device_id param_value_size)]
                [param_value_size_ret : (_ptr o _size_t)]
                -> [status : _cl_int]
                -> (cond
                     [(= status CL_SUCCESS)
                      param_value_size_ret]
                     [(= status CL_INVALID_GL_SHAREGROUP_REFERENCE_KHR)
                      (error 'clGetGLContextInfoKHR:length "CL_INVALID_GL_SHAREGROUP_REFERENCE_KHR")]
                     [(= status CL_INVALID_OPERATION)
                      (error 'clGetGLContextInfoKHR:length "CL_INVALID_OPERATION")]
                     [(= status CL_INVALID_VALUE)
                      (error 'clGetGLContextInfoKHR:length "CL_INVALID_VALUE")]
                     [(= status CL_OUT_OF_RESOURCES)
                      (error 'clGetGLContextInfoKHR:length "CL_OUT_OF_RESOURCES")]
                     [(= status CL_OUT_OF_HOST_MEMORY)
                      (error 'clGetGLContextInfoKHR:length "CL_OUT_OF_HOST_MEMORY")]
                     [else
                       (error 'clGetGLContextInfoKHR:length "Unknown error code: ~e" status)]))))
  (actual-function properties param_name 32))

(define (clGetGLContextInfoKHR:generic properties
                                       param_name)
  (cond
    [(not (= param_name CL_DEVICES_FOR_GL_CONTEXT_KHR))
     (error 'clGetGLContextInfoKHR:generic "CL_DEVICES_FOR_GL_CONTEXT_KHR is the only supported param_name")])

  (define actual-function
    (cast (clGetExtensionFunctionAddress "clGetGLContextInfoKHR")
          _pointer
          (_fun [properties : (_vector i _cl_context_properties)]
                [param_name : _cl_gl_context_info]
                [param_value_size : _size_t]
                [param_value : (_vector o _cl_device_id param_value_size)]
                [param_value_size_ret : _pointer = #f]
                -> [status : _cl_int]
                -> (cond
                     [(= status CL_SUCCESS)
                       param_value]
                     [(= status CL_INVALID_GL_SHAREGROUP_REFERENCE_KHR)
                      (error 'clGetGLContextInfoKHR:generic "CL_INVALID_GL_SHAREGROUP_REFERENCE_KHR")]
                     [(= status CL_INVALID_OPERATION)
                      (error 'clGetGLContextInfoKHR:generic "CL_INVALID_OPERATION")]
                     [(= status CL_INVALID_VALUE)
                      (error 'clGetGLContextInfoKHR:generic "CL_INVALID_VALUE")]
                     [(= status CL_OUT_OF_RESOURCES)
                      (error 'clGetGLContextInfoKHR:generic "CL_OUT_OF_RESOURCES")]
                     [(= status CL_OUT_OF_HOST_MEMORY)
                      (error 'clGetGLContextInfoKHR:generic "CL_OUT_OF_HOST_MEMORY")]
                     [else
                       (error 'clGetGLContextInfoKHR:length "Unknown error code: ~e" status)]))))
  (actual-function properties param_name 32))|#

(provide clGetGLContextInfoKHR:length
         clGetGLContextInfoKHR:generic)

(define-opencl-info-extension
  clGetGLContextInfoKHR
  (clGetGLContextInfoKHR:length clGetGLContextInfoKHR:generic)
  _cl_gl_context_info cl_gl_context_info/c
  (args [properties : (_vector i _cl_context_properties)])
  (error status
         (cond
           [(= status CL_INVALID_GL_SHAREGROUP_REFERENCE_KHR)
            (error 'clGetGLContextInfoKHR "CL_INVALID_GL_SHAREGROUP_REFERENCE_KHR")]
           [(= status CL_INVALID_OPERATION)
            (error 'clGetGLContextInfoKHR "CL_INVALID_OPERATION")]
           [(= status CL_INVALID_VALUE)
            (error 'clGetGLContextInfoKHR "CL_INVALID_VALUE")]
           [else
             (error 'clGetGLContextInfoKHR "Undefined error: ~e" status)]))
  (variable
    param_value_size
    [_cl_device_id*
      (_cvector o _cl_device_id param_value_size) (make-cvector _cl_device_id 0)
      _cl_device_id_vector/c
      CL_DEVICES_FOR_GL_CONTEXT_KHR])
  (fixed
    [_cl_device_id _cl_device_id/c
                   CL_CURRENT_DEVICE_FOR_GL_CONTEXT_KHR]))

(define-opencl clCreateFromGLBuffer
  (_fun [context : _cl_context]
        [flags : _cl_mem_flags]
        [bufobj : _cl_uint]
        [errcode_ret : (_ptr o _cl_int)]
        -> [cl-buf : _cl_mem/null]
        ->
        (cond
          [(= errcode_ret CL_SUCCESS)
           cl-buf]
          [(= errcode_ret CL_INVALID_CONTEXT)
           (error 'clCreateFromGLBuffer "~e is not a valid context"
                  context)]
          [(= errcode_ret CL_INVALID_VALUE)
           (error 'clCreateFromGLBuffer "values specified in ~e are not valid"
                  flags)]
          [(= errcode_ret CL_INVALID_GL_OBJECT)
           (error 'clCreateFromGLBuffer "~e is not a valid GL buffer object"
                  bufobj)]
          [(= errcode_ret CL_OUT_OF_RESOURCES "there is a failure to allocate resources required by the OpenCL implementation on the device")]
          [(= errcode_ret CL_OUT_OF_HOST_MEMORY "there is a failure to allocate resources required by the OpenCL implemetation on the host")]
          [else
            (error 'clCreateFromGLBuffer "Invalid error code: ~e"
                   errcode_ret)])))

(provide/doc
  (proc-doc/names
    clCreateFromGLBuffer
    (c:-> _cl_context/c _cl_mem_flags/c _cl_uint/c _cl_mem/c)
    (ctxt flags glbufobj)
    @{}))

(define-opencl clCreateFromGLTexture2D
  (_fun [context : _cl_context]
        [flags : _cl_mem_flags]
        [texture_target : _cl_uint]
        [miplevel : _cl_int]
        [texture : _cl_uint]
        [errcode_ret : (_ptr o _cl_int)]
        -> [cl-image : _cl_mem]
        ->
        (cond
          [(= errcode_ret CL_SUCCESS)
           cl-image]
          [(= errcode_ret CL_INVALID_CONTEXT)
           (error 'clCreateFromGLTexture2D "~e is not a valid context"
                  context)]
          [(= errcode_ret CL_INVALID_VALUE)
           (error 'clCreateFromGLTexture2D "values specified in ~e are not valid"
                  flags)]
          [(= errcode_ret CL_INVALID_MIP_LEVEL)
           (error 'clCreateFromGLTexture2D "~e is not a valid mip level or the OpenGL implementation does not allow mipmap levels greater than zero"
                  miplevel)]
          [(= errcode_ret CL_INVALID_GL_OBJECT)
           (error 'clCreateFromGLTexture2D "~e is not a valid GL texture object, or the specified miplevel of ~e is not defined, or the width or height of the specified miplevel is zero"
                  texture texture)]
          [(= errcode_ret CL_INVALID_IMAGE_FORMAT_DESCRIPTOR)
           (error 'clCreateFromGLTexture2D "the internal OpenGL texture format does not map to a supported OpenCL image format")]
          [(= errcode_ret CL_INVALID_OPERATION)
           (error 'clCreateFromGLTexture2D "the texture object ~e must not have a border width greater than zero"
                  texture)]
          [(= errcode_ret CL_OUT_OF_RESOURCES)
           (error 'clCreateFromGLTexture2D "there is a failure to allocate resources required b the OpenCL implementation on the device")]
          [(= errcode_ret CL_OUT_OF_HOST_MEMORY)
           (error 'clCreateFromGLTexture2D "there is a failure to allocate resources required by the OpenCL implementation on the host")]
          [else
            (error 'clCreateFromGLTexture2D "Invalid error code: ~e"
                   errcode_ret)])))

(provide/doc
  (proc-doc/names
    clCreateFromGLTexture2D
    (c:-> _cl_context/c _cl_mem_flags/c _cl_uint/c _cl_int/c _cl_uint/c _cl_mem/c)
    (ctxt flags texture-target miplevel texture)
    @{}))


(define-opencl clCreateFromGLRenderbuffer
  (_fun [context : _cl_context]
        [flags : _cl_mem_flags]
        [renderbuffer : _cl_uint]
        [errcode_ret : (_ptr o _cl_int)]
        -> [cl-image : _cl_mem/null]
        ->
        (cond
          [(= errcode_ret CL_SUCCESS)
           cl-image]
          [(= errcode_ret CL_INVALID_CONTEXT)
           (error 'clCreateFromGLRenderbuffer "~e is not a valid context"
                  context)]
          [(= errcode_ret CL_INVALID_VALUE)
           (error 'clCreateFromGLRenderbuffer "values specified in ~e are not valid"
                  flags)]
          [(= errcode_ret CL_INVALID_GL_OBJECT)
           (error 'clCreateFromGLRenderbuffer "~e is not a valid renderbuffer or the width or height of ~e is zero"
                  renderbuffer renderbuffer)]
          [(= errcode_ret CL_INVALID_IMAGE_FORMAT_DESCRIPTOR)
           (error 'clCreateFromGLRenderbuffer "the internal OpenGL texture format does not map to a supported OpenCL image format")]
          [(= errcode_ret CL_INVALID_OPERATION)
           (error 'clCreateFromGLRenderbuffer "~e must not be a multi-sample GL renderbuffer object"
                  renderbuffer)]
          [(= errcode_ret CL_OUT_OF_RESOURCES)
           (error 'clCreateFromGLRenderbuffer "there is a failure to allocate resources required b the OpenCL implementation on the device")]
          [(= errcode_ret CL_OUT_OF_HOST_MEMORY)
           (error 'clCreateFromGLRenderbuffer "there is a failure to allocate resources required by the OpenCL implementation on the host")]
          [else
            (error 'clCreateFromGLRenderbuffer "Invalid error code: ~e"
                   errcode_ret)])))

(provide/doc
  (proc-doc/names
    clCreateFromGLRenderbuffer
    (c:-> _cl_context/c _cl_mem_flags/c _cl_uint/c _cl_mem/c)
    (ctxt flags renderbuffer)
    @{}))

(define-opencl clGetGLObjectInfo:type clGetGLObjectInfo
  (_fun [memobj : _cl_mem]
        [gl_object_type : (_ptr o _cl_gl_object_type)]
        [gl_object_name : (_ptr o _cl_uint)]
        -> [errcode_ret : _cl_int]
        ->
        (cond
          [(= errcode_ret CL_SUCCESS)
           gl_object_type]
          [(= errcode_ret CL_INVALID_MEM_OBJECT)
           (error 'clGetGLObjectInfo:type "~e is not a valid OpenCL memory object"
                  memobj)]
          [(= errcode_ret CL_INVALID_GL_OBJECT)
           (error 'clGetGLObjectInfo:type "there is no GL object associated with ~e"
                  memobj)]
          [(= errcode_ret CL_OUT_OF_RESOURCES)
           (error 'clGetGLObjectInfo:type "there is a failure to allocate resources required by the implementation of OpenCL on the device")]
          [(= errcode_ret CL_OUT_OF_HOST_MEMORY)
           (error 'clGetGLObjectInfo:type "there is a failure to allocate resources required by the implementation of OpenCL on the host")]
          [else
            (error 'clGetGLObjectInfo:type "Invalid error code: ~e" errcode_ret)])))

(provide/doc
  (proc-doc/names
    clGetGLObjectInfo:type
    (c:-> _cl_mem/c _cl_gl_object_type/c)
    (memobj)
    @{}))

(define-opencl clGetGLObjectInfo:name clGetGLObjectInfo
  (_fun [memobj : _cl_mem]
        [gl_object_type : (_ptr o _cl_gl_object_type)]
        [gl_object_name : (_ptr o _cl_uint)]
        -> [errcode_ret : _cl_int]
        ->
        (cond
          [(= errcode_ret CL_SUCCESS)
           gl_object_name]
          [(= errcode_ret CL_INVALID_MEM_OBJECT)
           (error 'clGetGLObjectInfo:type "~e is not a valid OpenCL memory object"
                  memobj)]
          [(= errcode_ret CL_INVALID_GL_OBJECT)
           (error 'clGetGLObjectInfo:type "there is no GL object associated with ~e"
                  memobj)]
          [(= errcode_ret CL_OUT_OF_RESOURCES)
           (error 'clGetGLObjectInfo:type "there is a failure to allocate resources required by the implementation of OpenCL on the device")]
          [(= errcode_ret CL_OUT_OF_HOST_MEMORY)
           (error 'clGetGLObjectInfo:type "there is a failure to allocate resources required by the implementation of OpenCL on the host")]
          [else
            (error 'clGetGLObjectInfo:type "Invalid error code: ~e" errcode_ret)])))

(provide/doc
  (proc-doc/names
    clGetGLObjectInfo:name
    (c:-> _cl_mem/c _cl_uint/c)
    (memobj)
    @{}))

(define-opencl-info clGetGLTextureInfo
  (clGetGLTextureInfo:length clGetGLObjectInfo:generic)
  _cl_gl_texture_info _cl_gl_texture_info/c
  (args [memobj : _cl_mem _cl_mem/c])
  (error status
         (cond [(= status CL_INVALID_MEM_OBJECT)
                (error 'clGetGLTextureInfo "memobj is not a valid OpenCL memory object")]
               [(= status CL_INVALID_GL_OBJECT)
                (error 'clGetGLTextureInfo "there is no GL texture object associated with memobj")]
               [(= status CL_INVALID_VALUE)
                (error 'clGetGLTextureInfo "param_name is not one of the supported values OR size in bytes specified by param_value_size is < size of return type and param_value is not NULL OR param_value and param_value_size_ret are NULL")]
               [else
                 (error 'clGetGLTextureInfo "Invalid error code: ~e" status)]))
  (variable param_value_size)
  (fixed [_cl_uint _cl_uint/c
                   CL_GL_TEXTURE_TARGET]
         [_cl_int _cl_int/c
                  CL_GL_MIPMAP_LEVEL]))


(define-opencl clEnqueueAcquireGLObjects
  (_fun [command_queue : _cl_command_queue]
        [num_objects : _cl_uint]
        [mem_objects : (_ptr i _cl_mem)]
        [num_events_in_wait_list : _cl_uint]
        [event_wait_list : (_ptr i _cl_event/null)]
        [event : (_ptr o _cl_event/null)]
        -> [errcode_ret : _cl_int]
        ->
        (cond
          [(= errcode_ret CL_SUCCESS)
           event]
          [(= errcode_ret CL_INVALID_VALUE)
           (error 'clEnqueueAcquireGLObjects "num_objects is 0 and mem_objects is not a NULL value OR num_objects > 0 and mem_objects is NULL")]
          [(= errcode_ret CL_INVALID_MEM_OBJECT)
           (error 'clEnqueueAcquireGLObjects "at least one memory object in mem_objects is not a valid OpenCL memory object")]
          [(= errcode_ret CL_INVALID_COMMAND_QUEUE)
           (error 'clEnqueueAcquireGLObjects "command_queue is not a valid command queue")]
          [(= errcode_ret CL_INVALID_CONTEXT)
           (error 'clEnqueueAcquireGLObjects "context associated with command_queue was not created from an OpenGL context")]
          [(= errcode_ret CL_INVALID_GL_OBJECT)
           (error 'clEnqueueAcquireGLObjects "at least one memory object in mem_objects was not created from a GL object")]
          [(= errcode_ret CL_INVALID_EVENT_WAIT_LIST)
           (error 'clEnqueueAcquireGLObjects "event_wait_list is NULL and num_events_in_wait_list > 0 OR event_wait_list is not NULL and num_events_in_wait_list is 0, OR at least one event object in event_wait_list is not a valid event")]
          [(= errcode_ret CL_OUT_OF_RESOURCES)
           (error 'clEnqueueAcquireGLObjects "there is a failure to allocate resources required by the implementation of OpenCL on the device")]
          [(= errcode_ret CL_OUT_OF_HOST_MEMORY)
           (error 'clEnqueueAcquireGLObjects "there is a failure to allocate resources required by the implementation of OpenCL on the host")]

          [else
            (error 'clEnqueueAcquireGLObjects "Invalid error code: ~e" errcode_ret)])))

(provide/doc
  (proc-doc/names
    clEnqueueAcquireGLObjects
    (c:-> _cl_command_queue/c
          _cl_uint/c
          _cl_mem/c
          _cl_uint/c
          _cl_event/null/c
          _cl_event/null/c)
    (command_queue
      num_objects
      mem_objects
      num_events_in_wait_ist
      event_wait_list)
    @{}))

;clEnqueueReleaseGLObjects


(define-opencl clEnqueueReleaseGLObjects
  (_fun [command_queue : _cl_command_queue]
        [num_objects : _cl_uint]
        [mem_objects : (_ptr i _cl_mem)]
        [num_events_in_wait_list : _cl_uint]
        [event_wait_list : (_ptr i _cl_event/null)]
        [event : (_ptr o _cl_event/null)]
        -> [errcode_ret : _cl_int]
        ->
        (cond
          [(= errcode_ret CL_SUCCESS)
           event]
          [(= errcode_ret CL_INVALID_VALUE)
           (error 'clEnqueueReleaseGLObjects "num_objects is 0 and mem_objects is not a NULL value OR num_objects > 0 and mem_objects is NULL")]
          [(= errcode_ret CL_INVALID_MEM_OBJECT)
           (error 'clEnqueueReleaseGLObjects "at least one memory object in mem_objects is not a valid OpenCL memory object")]
          [(= errcode_ret CL_INVALID_COMMAND_QUEUE)
           (error 'clEnqueueReleaseGLObjects "command_queue is not a valid command queue")]
          [(= errcode_ret CL_INVALID_CONTEXT)
           (error 'clEnqueueReleaseGLObjects "context associated with command_queue was not created from an OpenGL context")]
          [(= errcode_ret CL_INVALID_GL_OBJECT)
           (error 'clEnqueueReleaseGLObjects "at least one memory object in mem_objects was not created from a GL object")]
          [(= errcode_ret CL_INVALID_EVENT_WAIT_LIST)
           (error 'clEnqueueReleaseGLObjects "event_wait_list is NULL and num_events_in_wait_list > 0 OR event_wait_list is not NULL and num_events_in_wait_list is 0, OR at least one event object in event_wait_list is not a valid event")]
          [(= errcode_ret CL_OUT_OF_RESOURCES)
           (error 'clEnqueueReleaseGLObjects "there is a failure to allocate resources required by the implementation of OpenCL on the device")]
          [(= errcode_ret CL_OUT_OF_HOST_MEMORY)
           (error 'clEnqueueReleaseGLObjects "there is a failure to allocate resources required by the implementation of OpenCL on the host")]

          [else
            (error 'clEnqueueReleaseGLObjects "Invalid error code: ~e" errcode_ret)])))

(provide/doc
  (proc-doc/names
    clEnqueueReleaseGLObjects
    (c:-> _cl_command_queue/c
          _cl_uint/c
          _cl_mem/c
          _cl_uint/c
          _cl_event/null/c
          _cl_event/null/c)
    (command_queue
      num_objects
      mem_objects
      num_events_in_wait_ist
      event_wait_list)
    @{}))

