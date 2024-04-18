module SOPHYSM

using QML

export start_GUI
export getDir
export setDir

global dir = @__DIR__

function getDir()
    return dir
end

function setDir!(folderPath:: AbstractString)
    dir = folderPath                       
    println(dir)
end

function start_GUI()
    qmlfile = joinpath(@__DIR__, "qml", "SOPHYSM.qml")
    qmlfunction("getDir", getDir)
    qmlfunction("setDir", setDir!)

    # All keyword arguments to load are added as context properties on the QML side
    loadqml(qmlfile, fromcontext="From context property")

    exec()

    println("GUI Closed")
end

start_GUI();

end
