{spawn} = require 'child_process'
stream = require './stream'
os = require 'os'

##=======================================================================

_log = (x) -> console.warn x.toString('utf8')
exports.set_log = set_log = (log) -> _log = log

##=======================================================================

exports.Engine = class Engine

  #---------------

  constructor : ({@args, @stdin, @stdout, @stderr, @name, @opts}) ->

    @stderr or= new stream.FnOutStream(_log)
    @stdin or= new stream.NullInStream()
    @stdout or= new stream.NullOutStream()
    @opts or= {}

    @_exit_code = null
    @_exit_cb = null
    @_err = null
    @_n_out = 0

  #---------------

  _spawn : () ->
    args = @args
    name = @name
    if os.platform() is 'windows'
      args = [ name, "/c", "/s" ].concat args
      name = "cmd"
    @proc = spawn name, args, @opts

  #---------------

  run : () ->
    @_spawn()
    @stdin.pipe @proc.stdin
    @proc.stdout.pipe @stdout
    @proc.stderr.pipe @stderr
    @pid = @proc.pid
    @_n_out = 3 # we need 3 exit events before we can exit
    @proc.on 'exit', (status) => @_got_exit status
    @proc.stdout.on 'end', () => @_got_eof()
    @proc.stderr.on 'end', () => @_got_eof()
    @proc.on 'error', (err)   => @_got_error err
    @

  #---------------

  _got_exit : (status) ->
    @_exit_code = status
    @proc = null
    @pid = -1
    @_maybe_call_callback()

  #---------------

  _got_error : (err) ->
    @_err = err
    @proc = null
    @pid = -1
    @_maybe_call_callback()

  #---------------

  _got_eof : () ->
    --@_n_out
    @_maybe_call_callback()

  #---------------

  _can_finish : () -> @_err or (@_n_out <= 0 && @_exit_code?)

  #---------------

  _maybe_call_callback : () ->
    if @_exit_cb? and @_can_finish()
      ecb = @_exit_cb
      @_exit_cb = null
      cb @_err, @_exit_code

  #---------------

  wait : (cb) ->
    @_exit_cb = cb
    @_maybe_call_callback()

##=======================================================================

exports.bufferify = bufferify = (x) ->
  if not x? then null
  else if (typeof x is 'string') then new Buffer x, 'utf8'
  else if (Buffer.isBuffer x) then x
  else null

##=======================================================================

exports.run = run = (inargs, cb) ->
  {args, stdin, stdout, stderr, quiet, name, eklass, opts} = inargs

  if (b = bufferify stdin)?
    stdin = new stream.BufferInStream b
  if quiet
    stderr = new stream.NullOutStream()
  if not stdout?
    def_out = true
    stdout = new stream.BufferOutStream()
  else
    def_out = false
  err = null
  await (new Engine { args, stdin, stdout, stderr, name, opts}).run().wait defer err, rc
  if err and (rc isnt 0)
    eklass or= Error
    err = new eklass "exit code #{rc}"
    err.rc = rc
  out = if def_out? then stdout.data() else null
  cb err, out

##=======================================================================
