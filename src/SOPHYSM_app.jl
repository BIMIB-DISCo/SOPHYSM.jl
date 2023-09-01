### -*- Mode: Julia -*-

### SOPHYSM - SOlid tumors PHYlogentic Spatial Modeller.
### SOPHYSM_app.jl

## Packages
using Gtk

## Import .glade file
SOPHYSM_app = GtkBuilder(filename = "SOPHYSM.glade")

## Data from SOPHYSM.glade
mainWindow = SOPHYSM_app["mainWindow"]
thresholdDialog = SOPHYSM_app["thresholdDialog"]
newProjectDialog = SOPHYSM_app["newProjectDialog"]
projectAlreadyExistMessage = SOPHYSM_app["projectAlreadyExistMessage"]
invalidNameProjectMessage = SOPHYSM_app["invalidNameProjectMessage"]
loadProjectDialog = SOPHYSM_app["loadProjectDialog"]
## menuBar
newProjectButton = SOPHYSM_app["newProjectButton"]
loadProjectButton = SOPHYSM_app["loadProjectButton"]
closeProjectButton = SOPHYSM_app["closeProjectButton"]
quitButton = SOPHYSM_app["quitButton"]
loadImageButton = SOPHYSM_app["loadImageButton"]
## ProjectBox
segmentationButton = SOPHYSM_app["segmentationButton"]
simulationButton = SOPHYSM_app["simulationButton"]
loadButton = SOPHYSM_app["loadButton"]
descriptionLabel = SOPHYSM_app["descriptionLabel"]
## thresholdDialog
thresholdOkButton = SOPHYSM_app["thresholdOkButton"]
thresholdCancelButton = SOPHYSM_app["thresholdCancelButton"]
thresholdGreyscaleEntry = SOPHYSM_app["thresholdGreyscaleEntry"]
thresholdMarkersEntry = SOPHYSM_app["thresholdMarkersEntry"]
## newProjectDialog
newProjectOkButton = SOPHYSM_app["newProjectOkButton"]
newProjectCancelButton = SOPHYSM_app["newProjectCancelButton"]
projectNameLabel = SOPHYSM_app["projectNameLabel"]
projectNameEntry = SOPHYSM_app["projectNameEntry"]
# errorNameMessage
errorNameCancelButton = SOPHYSM_app["errorNameCancelButton"]
# invalidNameMessage
invalidNameProjectButton = SOPHYSM_app["invalidNameProjectButton"]
## loadProjectDialog
loadProjectOkButton = SOPHYSM_app["loadProjectOkButton"]
loadProjectCancelButton = SOPHYSM_app["loadProjectCancelButton"]

## Button Listener
signal_connect(segmentationButton, "button-press-event") do widget, event
    run(thresholdDialog)
end

## menuBar Buttons
signal_connect(newProjectButton, "button-press-event") do widget, event
    run(newProjectDialog)
end

signal_connect(loadProjectButton, "button-press-event") do widget, event
    run(loadProjectDialog)
end

signal_connect(closeProjectButton, "button-press-event") do widget, event
    ##
end

signal_connect(quitButton, "button-press-event") do widget, event
    destroy(mainWindow)
    destroy(thresholdDialog)
    destroy(newProjectDialog)
    destroy(projectAlreadyExistMessage)
    destroy(invalidNameProjectMessage)
end

signal_connect(loadImageButton, "button-press-event") do widget, event
    ##
end

## newProjectDialog elements
signal_connect(newProjectDialog, "delete-event") do widget, event
    hide(newProjectDialog)
end

signal_connect(newProjectOkButton, "button-press-event") do widget, event
    filename = get_gtk_property(projectNameEntry, :text, String)
    filepath_directory = joinpath(@__DIR__, "..", "workspace", filename)
    if filename == ""
        run(invalidNameProjectMessage)
    else
        if isdir(filepath_directory)
            run(projectAlreadyExistMessage)
        else
            # Build Project Folder
            mkdir(filepath_directory)
            hide(newProjectDialog)
            set_gtk_property!(descriptionLabel, :label, "Project Name : "*filename)
            set_gtk_property!(loadButton, :sensitive, true)
            set_gtk_property!(loadImageButton, :sensitive, true)
        end
    end
end

signal_connect(newProjectCancelButton, "button-press-event") do widget, event
    hide(newProjectDialog)
end
# errorNameMessage element
signal_connect(errorNameCancelButton, "button-press-event") do widget, event
    hide(projectAlreadyExistMessage)
end
# invalidNameMessage element
signal_connect(invalidNameProjectButton, "button-press-event") do widget, event
    hide(invalidNameProjectMessage)
end

## loadProjectDialog elements
signal_connect(loadProjectDialog, "delete-event") do widget, event
    hide(loadProjectDialog)
end

signal_connect(loadProjectOkButton, "button-press-event") do widget, event
    get_gtk_property(loadProjectDialog, :label, String)
    hide(loadProjectDialog)
end

signal_connect(loadProjectCancelButton, "button-press-event") do widget, event
    hide(loadProjectDialog)
end


showall(mainWindow)

### end of file -- SOPHYSM_app.jl
