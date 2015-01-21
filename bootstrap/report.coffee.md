
# Bootstrap Report

    exports = module.exports = []

    exports.push required: true, handler: (ctx) ->
      report = ctx.config.report ?= {}
      report.writer ?= {}
      report.writer.write ?= (data) ->
        process.stdout.write data

    exports.push name: 'Bootstrap # Report Console', required: true, handler: (ctx, next) ->
      {writer} = ctx.config.report
      reports = {}
      ctx.report = (k, v) ->
        reports[k] = v
      ctx.on 'middleware_start', (status) ->
        reports = {}
      ctx.on 'middleware_stop', (err) ->
        for k, v of reports
          writer.write if arguments.length > 1 then "#{colors.green.dim k}: #{colors.green v}\n" else "#{k}\n"
      next null, ctx.PASS

# Dependencies

    colors = require 'colors/safe'