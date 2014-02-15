
{run} = require '../../lib/main'

exports.launch_true = (T,cb) ->
  await run { name : "true" }, defer err
  T.no_error err
  cb()

exports.launch_false = (T, cb) ->
  await run { name : 'false' }, defer err
  T.assert err?, "error came back"
  T.assert err.rc?, "got an error code!"
  T.assert (err.rc != 0), "...that wasn't 0"
  cb()

exports.launch_not_there = (T,cb) ->
  await run { name : 'a_process_that_does_not_exist', quiet : true }, defer err
  T.assert err?, "error came back"
  T.equal err?.errno, 'ENOENT', "the ENOENT came back"
  cb()

exports.check_stdout = (T,cb) ->
  await run { name : "echo", args : [ "hello", "world"] }, defer err, out
  T.no_error err
  T.equal out.toString('utf8'), "hello world\n", "got the right output"
  cb()  
