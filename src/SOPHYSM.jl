module SOPHYSM

using QML
using Observables
using Base.Filesystem
using JSON

### Included modules
include("Workspace.jl")

export get_workspace_dir, set_workspace_dir

export start_GUI

const workspace_dir = Observable(get_workspace_dir())

function start_GUI()

    qmlfile = joinpath(@__DIR__, "qml", "SOPHYSM.qml")

    # Propmap
    propmap = JuliaPropertyMap()
    propmap["workspace_dir"] = workspace_dir

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

end # SOPHYSM module
