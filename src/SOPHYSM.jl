### SOPHYSM-- SOlid tumors PHYlogentic Spatial Modeller
### SOPHYSM.jl

module SOPHYSM

### Packages
using QML
using Observables
using Base.Filesystem
using JSON

### Included modules
include("Workspace.jl")

### Exported functions
export start_GUI

### Constants
const workspace_dir = Observable(get_workspace_dir())

### Main Functions
# some functions

function pushCollection(collectionName::AbstractString)
    collectionName = QString(collectionName)
    push!(collections_to_download, collectionName)
end

### GUI logic
function start_GUI()
    qmlfile = joinpath(@__DIR__, "qml", "SOPHYSM.qml")

    ### QML Functions
    # qml function that needs to be exported

    # Propmap
    propmap = JuliaPropertyMap()
    propmap["workspace_dir"] = workspace_dir
    # TODO: propmap["collections_to_download"] = collections_to_download

    # Listening if there is any changes on workspace_dir
    on(workspace_dir) do x
        set_workspace_dir(x)
        println("WS changed to ", workspace_dir)
    end

    # All keyword arguments to load are added as context properties on the QML side
    loadqml(qmlfile, propmap = propmap)
    
    exec()

    println("GUI Closed")
end

start_GUI()

# SOPHYSM module
end
