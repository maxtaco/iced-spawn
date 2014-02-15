{exec,spawn} = require 'child_process'
stream = require './stream'
util = require 'util'

##=======================================================================

_log = (x) -> console.warn x.toString('utf8')
_engine = null
exports.set_log = set_log = (log) -> _log = log
exports.set_default_engine = (e) -> _engine = e
_quiet = null
exports.set_default_quiet = (q) -> _quiet = q

##=======================================================================

class BaseEngine

  #---------------

  constructor : ({@args, @stdin, @stdout, @stderr, @name, @opts}) ->
    @stderr or= new stream.FnOutStream(_log)
    @stdin or= new stream.NullInStream()
    @stdout or= new stream.NullOutStream()
    @opts or= {}
    @args or= []
    @_exit_cb = null

  #---------------

  _maybe_call_callback : () ->
    if @_exit_cb? and @_can_finish()
      cb = @_exit_cb
      @_exit_cb = null
      cb @_err, @_exit_code

  #---------------

  wait : (cb) ->
    @_exit_cb = cb
    @_maybe_call_callback()

##=======================================================================

exports.SpawnEngine = class SpawnEngine extends BaseEngine

  #---------------

  constructor : ({args, stdin, stdout, stderr, name, opts}) ->
    super { args, stdin, stdout, stderr, name, opts }

    @_exit_code = null
    @_err = null
    @_win32 = (process.platform is 'win32')
    @_closed = false

  #---------------

  _spawn : () ->
    args = @args
    name = @name
    opts = @opts
    if @_win32
      args = [ "/s", "/c", '"' + [ name ].concat(args).join(" ") + '"' ]
      name = "cmd.exe"
      # shallow copy to not mess with what's passed to us
      opts = util._extend({}, @opts)
      opts.windowsVerbatimArguments = true
    @proc = spawn name, args, opts

  #---------------

  run : () ->
    @_spawn()
    @stdin.pipe @proc.stdin
    @proc.stdout.pipe @stdout
    @proc.stderr.pipe @stderr
    @pid = @proc.pid
    @proc.on 'exit', (status) => @_got_exit status
    @proc.on 'error', (err)   => @_got_error err
    @proc.on 'close', (code)  => @_got_close code
    @

  #---------------

  _got_close : (code) -> 
    @_closed = true
    @_maybe_call_callback()

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

  _can_finish : () -> (@_err? or @_exit_code?) and @_closed


##=======================================================================

exports.ExecEngine = class ExecEngine extends BaseEngine

  #---------------

  constructor : ({args, stdin, stdout, stderr, name, opts}) ->
    super { args, stdin, stdout, stderr, name, opts }
    @_exec_called_back = false

  #---------------

  run : () ->
    argv = [@name].concat(@args).join(" ")
    @proc = exec argv, @opts, (args...) => @_got_exec_cb args...
    @stdin.pipe @proc.stdin
    @

  #---------------

  _got_exec_cb : (err, stdout, stderr) ->
    await 
      @stdout.write stdout, defer()
      @stderr.write stderr, defer()
    @_err = err

    # Please excuse the plentiful hacks here.
    if not @_err?
      @_exit_code = 0
    else if @_err? 
      if @_err.code is 127
        @_err.errno = 'ENOENT'
      else
        @_exit_code = @_err.code
        @_err = null
        
    @_exec_called_back = true
    @_maybe_call_callback()

  #---------------

  _can_finish : () -> @_exec_called_back

##=======================================================================

exports.Engine = SpawnEngine

##=======================================================================

exports.bufferify = bufferify = (x) ->
  if not x? then null
  else if (typeof x is 'string') then new Buffer x, 'utf8'
  else if (Buffer.isBuffer x) then x
  else null

##=======================================================================

exports.run = run = (inargs, cb) ->
  {args, stdin, stdout, stderr, quiet, name, eklass, opts, engklass} = inargs

  if (b = bufferify stdin)?
    stdin = new stream.BufferInStream b
  if (quiet or (_quiet? and _quiet)) and not stderr?
    stderr = new stream.NullOutStream()
  if not stdout?
    def_out = true
    stdout = new stream.BufferOutStream()
  else
    def_out = false
  err = null
  engklass or= (_engine or SpawnEngine)
  await (new engklass { args, stdin, stdout, stderr, name, opts}).run().wait defer err, rc
  if not err? and (rc isnt 0)
    eklass or= Error
    err = new eklass "exit code #{rc}"
    err.rc = rc
  out = if def_out? then stdout.data() else null
  cb err, out

##=======================================================================
