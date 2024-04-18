module SOPHYSM

using QML
using Observables

export start_GUI, getDir, setDir!

# global dir = Observable(@__DIR__)
global dir = @__DIR__

function getDir()
    return dir
end

function setDir!(uri)
    dir = QString(uri)
    println("new workspace directory selected: $dir")
end

function start_GUI()

    qmlfunction("getDir", getDir)
    qmlfunction("setDir", setDir!)

    qmlfile = joinpath(@__DIR__, "qml", "SOPHYSM.qml")

    # Setting application context
    # propmap = QML.QQmlPropertyMap()
    # propmap["workspace_directory"] = dir
    # All keyword arguments to load are added as context properties on the QML side
    loadqml(qmlfile, workspace_directory = dir)

    exec()

    println("GUI Closed")
end

end
