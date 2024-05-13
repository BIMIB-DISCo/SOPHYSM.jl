### SOPHYSM-- SOlid tumors PHYlogentic Spatial Modeller
### SOPHYSM.jl

module SOPHYSM

### Packages
using QML
using Observables
using JSON
using JHistint

### Included modules
include("Workspace.jl")
include("SOPHYSMLogger.jl")

### Exported functions
export start_GUI

### Constants
workspace_dir = Observable(Workspace.get_workspace_dir())

### Main Functions

### GUI logic
function start_GUI()
    SOPHYSM_open_logger()
    SOPHYSM_log_message("@info", "Start GUI")

    workspace_dir = Observable(Workspace.get_workspace_dir())
    Workspace.set_environment()

    qmlfile = joinpath(@__DIR__, "qml", "SOPHYSM.qml")

    ### QML Functions
    qmlfunction("download_single_slide_from_collection", async_download_single_slide_from_collection)
    qmlfunction("log_message", SOPHYSM_log_message)

    # Propmap
    propmap = JuliaPropertyMap()
    propmap["workspace_dir"] = workspace_dir

    # Listening if there is any changes on workspace_dir
    on(workspace_dir) do x
        Workspace.set_workspace_dir(x)
        workspace_dir = Observable(Workspace.get_workspace_dir())
        log_message("@info", "WS Changed to $workspace_dir")
    end

    # All keyword arguments to load are added as context properties on the QML side
    loadqml(qmlfile, propmap = propmap)
    
    exec_async()

    SOPHYSM_log_message("@info", "Close GUI")
    SOPHYSM_close_logger()
end

end # SOPHYSM module