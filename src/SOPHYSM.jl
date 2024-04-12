module SOPHYSM

using QML

export start_GUI

function start_GUI()

    qmlfile = joinpath(@__DIR__, "qml", "SOPHYSM.qml")

    fromfunction() = "From function call"
    @qmlfunction fromfunction

    # All keyword arguments to load are added as context properties on the QML side
    loadqml(qmlfile, fromcontext="From context property")
    exec()

    "GUI Closed"
end

end