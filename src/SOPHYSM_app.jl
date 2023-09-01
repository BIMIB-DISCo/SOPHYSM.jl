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
## errorNameMessage
errorNameCancelButton = SOPHYSM_app["errorNameCancelButton"]
## invalidNameMessage
invalidNameProjectButton = SOPHYSM_app["invalidNameProjectButton"]

## Button Listener
signal_connect(segmentationButton, "button-press-event") do widget, event
    showall(thresholdDialog)
end

id_new_project = signal_connect(newProjectButton, "button-press-event") do widget, event
    showall(newProjectDialog)
end

# newProjectDialog element
id_new_project_1 = signal_connect(newProjectOkButton, "button-press-event") do widget, event
    filename = get_gtk_property(projectNameEntry, :text, String)
    filepath_directory = joinpath(@__DIR__, "..", "workspace", filename)
    if filename == ""
        showall(invalidNameProjectMessage)
    else
        if isdir(filepath_directory)
            showall(projectAlreadyExistMessage)
        else
            # Build Project Folder
            mkdir(filepath_directory)
        end
    end
end

signal_connect(newProjectCancelButton, "button-press-event") do widget, event
    destroy(newProjectDialog)
end

# errorNameMessage element
signal_connect(errorNameCancelButton, "button-press-event") do widget, event
    destroy(projectAlreadyExistMessage)
end

# invalidNameMessage element
signal_connect(invalidNameProjectButton, "button-press-event") do widget, event
    destroy(invalidNameProjectMessage)
end

# quitButton
signal_connect(quitButton, "button-press-event") do widget, event
    destroy(mainWindow)
    destroy(thresholdDialog)
    destroy(newProjectDialog)
    destroy(projectAlreadyExistMessage)
    destroy(invalidNameProjectMessage)
end

showall(mainWindow)

## FIX SECOND OPENING DIALOG
### end of file -- SOPHYSM_app.jl
