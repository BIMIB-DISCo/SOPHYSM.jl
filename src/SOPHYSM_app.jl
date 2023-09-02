### -*- Mode: Julia -*-

### SOPHYSM - SOlid tumors PHYlogentic Spatial Modeller.
### SOPHYSM_app.jl

### Packages
using Gtk

### Data from SOPHYSM.glade
SOPHYSM_app = GtkBuilder(filename = "SOPHYSM.glade")
mainWindow = SOPHYSM_app["mainWindow"]
thresholdDialog = SOPHYSM_app["thresholdDialog"]
newProjectDialog = SOPHYSM_app["newProjectDialog"]
projectAlreadyExistMessage = SOPHYSM_app["projectAlreadyExistMessage"]
invalidNameProjectMessage = SOPHYSM_app["invalidNameProjectMessage"]
slideAlreadyExistMessage = SOPHYSM_app["slideAlreadyExistMessage"]
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
# projectAlreadyExistMessage
errorNameCancelButton = SOPHYSM_app["errorNameCancelButton"]
# invalidNameMessage
invalidNameProjectButton = SOPHYSM_app["invalidNameProjectButton"]
# slideAlreadyExistMessage
errorSlideOkButton = SOPHYSM_app["errorSlideOkButton"]
errorSlideCancelButton = SOPHYSM_app["errorSlideCancelButton"]
## images data
selectedImage = SOPHYSM_app["selectedImage"]
segmentedImage = SOPHYSM_app["segmentedImage"]
## Variables
path_project_folder = ""
path_slide_folder = ""
filepath_slide_to_segment = ""
filepath_slide = ""
project_name = ""
slide_name = ""

###  BUTTON LISTENER
## menuBar Buttons
signal_connect(newProjectButton, "button-press-event") do widget, event
    run(newProjectDialog)
end

signal_connect(loadProjectButton, "button-press-event") do widget, event
    global path_project_folder =
        open_dialog("SOPHYSM - Select Project Folder",
                    action=GtkFileChooserAction.SELECT_FOLDER)
    if path_project_folder != ""
        if Sys.iswindows()
            res = split(path_project_folder, "\\")
        elseif Sys.isunix()
            res = split(path_project_folder, "/")
        end
        data = []
        for i in res
            push!(data, i)
        end
        global project_name = data[end]
        set_gtk_property!(descriptionLabel, :label, "Project Name : "*project_name)
        set_gtk_property!(loadButton, :sensitive, true)
        set_gtk_property!(loadImageButton, :sensitive, true)
    end
end

signal_connect(closeProjectButton, "button-press-event") do widget, event
    set_gtk_property!(loadButton, :sensitive, false)
    set_gtk_property!(loadImageButton, :sensitive, false)
    set_gtk_property!(segmentationButton, :sensitive, false)
    set_gtk_property!(simulationButton, :sensitive, false)
    set_gtk_property!(descriptionLabel, :label, "Project Name : ______________________")
    set_gtk_property!(selectedImage, :file, "")
    set_gtk_property!(segmentedImage, :file, "")
end

signal_connect(quitButton, "button-press-event") do widget, event
    destroy(mainWindow)
    destroy(thresholdDialog)
    destroy(newProjectDialog)
    destroy(projectAlreadyExistMessage)
    destroy(invalidNameProjectMessage)
end

signal_connect(loadImageButton, "button-press-event") do widget, event
    global filepath_slide =
        open_dialog("SOPHYSM - Select Histological Image",
                    GtkNullContainer(),
                    ("*.tif",
                     "*.png",
                     "*.jpg",
                     GtkFileFilter("*.tif, *.png, *.jpg",
                                   name = "All supported formats")))
   if filepath_slide != ""
       set_gtk_property!(selectedImage, :file, filepath_slide)
       set_gtk_property!(segmentationButton, :sensitive, true)
       # Build directory for loaded image
       if Sys.iswindows()
           res = split(filepath_slide, "\\")
       elseif Sys.isunix()
           res = split(filepath_slide, "/")
       end
       data = []
       for i in res
           push!(data, i)
       end
       global slide_name = data[end]
       if Sys.iswindows()
           global path_slide_folder = path_project_folder * "\\" * slide_name
       elseif Sys.isunix()
           global path_slide_folder = path_project_folder * "/" * slide_name
       end
       global path_slide_folder = replace(path_slide_folder, r"....$" => "")
       if isdir(path_slide_folder)
           run(slideAlreadyExistMessage)
       else
           mkdir(path_slide_folder)
           if Sys.iswindows()
               global filepath_slide_to_segment = path_slide_folder * "\\" * slide_name
           elseif Sys.isunix()
               global filepath_slide_to_segment = path_slide_folder * "/" * slide_name
           end
           cp(filepath_slide, filepath_slide_to_segment)
       end
   end
end

# slideAlreadyExistMessage elements
signal_connect(errorSlideOkButton, "button-press-event") do widget, event
    rm(path_slide_folder, force=true, recursive=true)
    mkdir(path_slide_folder)
    if Sys.iswindows()
        global filepath_slide_to_segment = path_slide_folder * "\\" * slide_name
    elseif Sys.isunix()
        global filepath_slide_to_segment = path_slide_folder * "/" * slide_name
    end
    cp(filepath_slide, filepath_slide_to_segment)
    hide(slideAlreadyExistMessage)
end

signal_connect(errorSlideCancelButton, "button-press-event") do widget, event
    hide(slideAlreadyExistMessage)
    set_gtk_property!(segmentationButton, :sensitive, false)
    ### SHOW OLD RESULT
end
## newProjectDialog elements
signal_connect(newProjectDialog, "delete-event") do widget, event
    hide(newProjectDialog)
end

signal_connect(newProjectOkButton, "button-press-event") do widget, event
    global project_name = get_gtk_property(projectNameEntry, :text, String)
    global path_project_folder = joinpath(@__DIR__, "..", "workspace", project_name)
    if project_name == ""
        run(invalidNameProjectMessage)
    else
        if isdir(path_project_folder)
            run(projectAlreadyExistMessage)
        else
            # Build Project Folder
            mkdir(path_project_folder)
            hide(newProjectDialog)
            set_gtk_property!(descriptionLabel, :label, "Project Name : "*project_name)
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

## thresholdDialog elements

## ProjectBox elements
signal_connect(loadButton, "button-press-event") do widget, event
    global filepath_slide =
        open_dialog("SOPHYSM - Select Histological Image",
                    GtkNullContainer(),
                    ("*.tif",
                     "*.png",
                     "*.jpg",
                     GtkFileFilter("*.tif, *.png, *.jpg",
                                   name = "All supported formats")))
   if filepath_slide != ""
       set_gtk_property!(selectedImage, :file, filepath_slide)
       set_gtk_property!(segmentationButton, :sensitive, true)
       # Build directory for loaded image
       if Sys.iswindows()
           res = split(filepath_slide, "\\")
       elseif Sys.isunix()
           res = split(filepath_slide, "/")
       end
       data = []
       for i in res
           push!(data, i)
       end
       global slide_name = data[end]
       if Sys.iswindows()
           global path_slide_folder = path_project_folder * "\\" * slide_name
       elseif Sys.isunix()
           global path_slide_folder = path_project_folder * "/" * slide_name
       end
       global path_slide_folder = replace(path_slide_folder, r"....$" => "")
       if isdir(path_slide_folder)
           run(slideAlreadyExistMessage)
       else
           mkdir(path_slide_folder)
           if Sys.iswindows()
               global filepath_slide_to_segment = path_slide_folder * "\\" * slide_name
           elseif Sys.isunix()
               global filepath_slide_to_segment = path_slide_folder * "/" * slide_name
           end
           cp(filepath_slide, filepath_slide_to_segment)
       end
   end
end

signal_connect(segmentationButton, "button-press-event") do widget, event

end

signal_connect(simulationButton, "button-press-event") do widget, event

end


showall(mainWindow)

### end of file -- SOPHYSM_app.jl
