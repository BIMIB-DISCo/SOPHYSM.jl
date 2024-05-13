### -*- Mode: Julia -*-

### SOPHYSMLogger -- SOPHYSM
### SOPHYSMLogger.jl

### Packages
using Logging
using Dates

### Exported functions
export SOPHYSM_log_message
export SOPHYSM_close_logger
export SOPHYSM_open_logger

"""
    open_logger()

Function to setup and open loggers (console and file io)
"""
function SOPHYSM_open_logger()
    global io = open(joinpath(Workspace.CONFIG_DIR, "SOPHYSMLog.txt"), "w+")
    global logger = SimpleLogger(io)
    global console = ConsoleLogger(stdout)
end

"""
    log_message(level::AbstractString, message::AbstractString)

Function to print log message on console and setup messages to print

# Arguments
- `level::AbstractString` = log level message
        [@debug, @info, @warn, @error]
- `message::AbstractString` = message to print
"""
function SOPHYSM_log_message(level::AbstractString, message::AbstractString)
    global_logger(console)
    message = string(message, " ", Dates.format(now(), RFC1123Format)) 
    expr = Meta.parse("$(Symbol(level))($(repr(message)))")
    eval(expr)
    global_logger(logger)
    eval(expr)
end

"""
    close_logger()

Function to print  on logfile.txt in CONFIG_DIR and close file io
"""
function SOPHYSM_close_logger()
    flush(io)
    close(io)
end