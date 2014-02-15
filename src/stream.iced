stream = require 'stream'

##=======================================================================

exports.NullInStream = class NullInStream extends stream.Readable
  _read : (sz) -> 
    @push null
    true

##=======================================================================

exports.NullOutStream = class NullOutStream extends stream.Writable
  _write : (dat, encoding, cb) -> cb()

##=======================================================================

exports.BufferInStream = class BufferInStream extends stream.Readable

  constructor : (@buf, options) ->
    super options

  _read : (sz) ->
    push_me = null
    if @buf.length > 0
      n = Math.min(sz,@buf.length)
      push_me = @buf[0...n]
      @buf = @buf[n...]
    @push push_me
    true

##=======================================================================

exports.BufferOutStream = class BufferOutStream extends stream.Writable

  constructor : (options) ->
    @_v = []
    super options

  _write : (dat, encoding, cb) -> 
    @_v.push dat
    cb()

  data : () -> Buffer.concat @_v

##=======================================================================

exports.FnOutStream = class FnOutStream extends stream.Writable
  constructor : (@fn, options) -> super options
  _write : (dat, encoding, cb) -> 
    @fn dat
    cb()

##=======================================================================

exports.grep = ({pattern, buffer}) ->
  lines = buffer.toString('utf8').split '\n' 
  out = (line for line in lines when line.match pattern)
  return out

##=======================================================================
