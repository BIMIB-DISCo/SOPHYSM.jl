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

### Exported functions
export start_GUI

### Constants
workspace_dir = Observable(Workspace.get_workspace_dir())

### Main Functions

### GUI logic
function start_GUI()
    workspace_dir = Observable(Workspace.get_workspace_dir())
    Workspace.set_environment()

    qmlfile = joinpath(@__DIR__, "qml", "SOPHYSM.qml")

    ### QML Functions
    qmlfunction("download_single_slide_from_collection", download_single_slide_from_collection)

    # Propmap
    propmap = JuliaPropertyMap()
    propmap["workspace_dir"] = workspace_dir

    # Listening if there is any changes on workspace_dir
    on(workspace_dir) do x
        Workspace.set_workspace_dir(x)
        workspace_dir = Observable(Workspace.get_workspace_dir())
        println("WS changed to ", workspace_dir)
    end

    # All keyword arguments to load are added as context properties on the QML side
    loadqml(qmlfile, propmap = propmap)
    
    exec()

    println("GUI Closed")
end

start_GUI()

end # SOPHYSM module