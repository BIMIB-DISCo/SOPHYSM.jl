module SOPHYSM

using QML

export start_GUI
export start_settings

function start_GUI()
    qmlfile = joinpath(@__DIR__, "qml", "SOPHYSM.qml")

    # All keyword arguments to load are added as context properties on the QML side
    loadqml(qmlfile, fromcontext="From context property")

    exec()

    println("GUI Closed")
end

start_GUI();

end
