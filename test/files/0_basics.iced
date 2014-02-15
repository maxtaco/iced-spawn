
{set_default_quiet,ExecEngine,set_default_engine, BufferOutStream,BufferInStream,run} = require '../../lib/main'

#=================================

win32 = (process.platform is 'win32')
CR = if process.platform is 'win32' then "\r" else ""
posix = not(win32)

#=================================

suite = 

  #----------------

  launch_true : (T,cb) ->
    await run { name : "true" }, defer err
    T.no_error err
    cb()

  #----------------

  launch_false : (T, cb) ->
    await run { name : 'false' }, defer err
    T.assert err?, "error came back"
    T.assert err.rc?, "got an error code!"
    T.assert (err.rc != 0), "...that wasn't 0"
    cb()

  #----------------

  launch_not_there_1 : (T,cb) ->
    await run { name : 'a_process_that_does_not_exist', quiet : true }, defer err
    T.assert err?, "error came back"
    if posix
      T.equal err?.errno, 'ENOENT', "the ENOENT came back"
    cb()

  #----------------

  launch_not_there_2 :(T,cb) ->
    stderr = new BufferOutStream()
    await run { name : 'a_process_that_does_not_exist', stderr }, defer err
    T.assert err?, "error came back"
    if posix
      T.equal err?.errno, 'ENOENT', "the ENOENT came back"
    T.assert stderr.data().length > 5, "we got some sort of error message back"
    cb()

  #----------------

  check_stdout : (T,cb) ->
    await run { name : "echo", args : [ "hello", "world"] }, defer err, out
    T.no_error err
    T.equal out.toString('utf8'), "hello world#{CR}\n", "got the right output"
    cb()  

  #----------------

  check_stdin_1 : (T, cb) ->
    msg = "Now is the time for all good men to come to the aid of the party."
    await run { name : "cat", stdin : msg }, defer err, out
    T.no_error err
    T.equal out.toString('utf8'), msg, "the same message came out as went in"
    cb()

  #----------------

  check_stdin_2 : (T, cb) ->
    msg = "Now is the time for all good men to come to the aid of the party."
    stream = new BufferInStream(new Buffer(msg, "utf8"))
    await run { name : "cat", stdin : stream }, defer err, out
    T.no_error err
    T.equal out.toString('utf8'), msg, "the same message came out as went in"
    cb()

#=================================

for k,v of suite
  exports["spawn_" + k ] = v
exports.change_to_exec = (T,cb) ->
  set_default_engine ExecEngine
  set_default_quiet true
  cb()
for k,v of suite
  exports["exec_" + k ] = v

