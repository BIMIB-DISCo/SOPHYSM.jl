### -*- Mode: Julia -*-

### SOPHYSM - SOlid tumors PHYlogentic Spatial Modeller.
### SOPHYSM_app.jl

### Packages
using Gtk
using JHistint
using J_Space

### Data from SOPHYSM.glade
SOPHYSM_app = GtkBuilder(filename = "SOPHYSM.glade")
mainWindow = SOPHYSM_app["mainWindow"]
thresholdDialog = SOPHYSM_app["thresholdDialog"]
newProjectDialog = SOPHYSM_app["newProjectDialog"]
projectAlreadyExistMessage = SOPHYSM_app["projectAlreadyExistMessage"]
invalidNameProjectMessage = SOPHYSM_app["invalidNameProjectMessage"]
slideAlreadyExistMessage = SOPHYSM_app["slideAlreadyExistMessage"]
thresholdErrorMessage = SOPHYSM_app["thresholdErrorMessage"]
chooseCollectionDialog = SOPHYSM_app["chooseCollectionDialog"]
## menuBar
newProjectButton = SOPHYSM_app["newProjectButton"]
loadProjectButton = SOPHYSM_app["loadProjectButton"]
closeProjectButton = SOPHYSM_app["closeProjectButton"]
quitButton = SOPHYSM_app["quitButton"]
loadImageButton = SOPHYSM_app["loadImageButton"]
downloadSingleCollectionButton = SOPHYSM_app["downloadSingleCollectionButton"]
downloadAllCollectionButton = SOPHYSM_app["downloadAllCollectionButton"]
## ProjectBox
segmentationButton = SOPHYSM_app["segmentationButton"]
simulationButton = SOPHYSM_app["simulationButton"]
loadButton = SOPHYSM_app["loadButton"]
descriptionLabel = SOPHYSM_app["descriptionLabel"]
## ResultBox
selectedImage = SOPHYSM_app["selectedImage"]
segmentedImage = SOPHYSM_app["segmentedImage"]
thresholdGreyscaleValueLabel = SOPHYSM_app["thresholdGreyscaleValueLabel"]
thresholdMarkersValueLabel = SOPHYSM_app["thresholdMarkersValueLabel"]
## thresholdDialog
thresholdOkButton = SOPHYSM_app["thresholdOkButton"]
thresholdCancelButton = SOPHYSM_app["thresholdCancelButton"]
defaultSettingsButton = SOPHYSM_app["defaultSettingsButton"]
thresholdGreyscaleEntry = SOPHYSM_app["thresholdGreyscaleEntry"]
thresholdMarkersEntry = SOPHYSM_app["thresholdMarkersEntry"]
# invalidThresholdMessage
thresholdErrorCancelButton = SOPHYSM_app["thresholdErrorCancelButton"]
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
## chooseCollectionDialog
collectionOkButton = SOPHYSM_app["collectionOkButton"]
collectionCancelButton = SOPHYSM_app["collectionCancelButton"]
nameCollectionEntry = SOPHYSM_app["nameCollectionEntry"]
## Variables
path_project_folder = ""
path_slide_folder = ""
filepath_slide_to_segment = ""
filepath_slide = ""
project_name = ""
slide_name = ""
threshold_gray = ""
threshold_marker = ""

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
        set_gtk_property!(descriptionLabel, :label,
                        "Project Name : " * project_name)
        set_gtk_property!(loadButton, :sensitive, true)
        set_gtk_property!(loadImageButton, :sensitive, true)
        set_gtk_property!(segmentationButton, :sensitive, false)
        set_gtk_property!(simulationButton, :sensitive, false)
        set_gtk_property!(selectedImage, :file, "")
        set_gtk_property!(segmentedImage, :file, "")
        set_gtk_property!(thresholdGreyscaleValueLabel, :label,
                        "Selected Greyscale Filter's Threshold : _____")
        set_gtk_property!(thresholdMarkersValueLabel, :label,
                        "Selected Marker's Distance Threshold : _____")
    end
end

signal_connect(closeProjectButton, "button-press-event") do widget, event
    set_gtk_property!(loadButton, :sensitive, false)
    set_gtk_property!(loadImageButton, :sensitive, false)
    set_gtk_property!(segmentationButton, :sensitive, false)
    set_gtk_property!(simulationButton, :sensitive, false)
    set_gtk_property!(descriptionLabel, :label,
                    "Project Name : ______________________")
    set_gtk_property!(selectedImage, :file, "")
    set_gtk_property!(segmentedImage, :file, "")
    set_gtk_property!(thresholdGreyscaleValueLabel, :label,
                    "Selected Greyscale Filter's Threshold : _____")
    set_gtk_property!(thresholdMarkersValueLabel, :label,
                    "Selected Marker's Distance Threshold : _____")
end

signal_connect(quitButton, "button-press-event") do widget, event
    destroy(mainWindow)
    destroy(thresholdDialog)
    destroy(newProjectDialog)
    destroy(projectAlreadyExistMessage)
    destroy(invalidNameProjectMessage)
    # ************** add destroy
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
       set_gtk_property!(simulationButton, :sensitive, false)
       set_gtk_property!(thresholdGreyscaleValueLabel, :label,
                       "Selected Greyscale Filter's Threshold : _____")
       set_gtk_property!(thresholdMarkersValueLabel, :label,
                       "Selected Marker's Distance Threshold : _____")
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

signal_connect(downloadSingleCollectionButton, "button-press-event") do widget, event
    run(chooseCollectionDialog)
end

signal_connect(downloadAllCollectionButton, "button-press-event") do widget, event
    # Call JHistInt
    # JHistint.download_single_collection(collection_name)
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
    set_gtk_property!(thresholdGreyscaleValueLabel, :label,
                    "Selected Greyscale Filter's Threshold : _____")
    set_gtk_property!(thresholdMarkersValueLabel, :label,
                    "Selected Marker's Distance Threshold : _____")
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
            set_gtk_property!(segmentationButton, :sensitive, false)
            set_gtk_property!(simulationButton, :sensitive, false)
            set_gtk_property!(selectedImage, :file, "")
            set_gtk_property!(segmentedImage, :file, "")
            set_gtk_property!(thresholdGreyscaleValueLabel, :label,
                            "Selected Greyscale Filter's Threshold : _____")
            set_gtk_property!(thresholdMarkersValueLabel, :label,
                            "Selected Marker's Distance Threshold : _____")
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

## chooseCollectionDialog elements
signal_connect(chooseCollectionDialog, "delete-event") do widget, event
    hide(chooseCollectionDialog)
end

signal_connect(collectionCancelButton, "button-press-event") do widget, event
    hide(chooseCollectionDialog)
end

signal_connect(collectionOkButton, "button-press-event") do widget, event
    collection_name = get_gtk_property(nameCollectionEntry, :text, String)
    # Call JHistInt
    # JHistint.download_single_collection(collection_name)
    hide(chooseCollectionDialog)
end

## thresholdDialog elements
signal_connect(thresholdDialog, "delete-event") do widget, event
    hide(thresholdDialog)
end

signal_connect(thresholdCancelButton, "button-press-event") do widget, event
    hide(thresholdDialog)
end

signal_connect(thresholdOkButton, "button-press-event") do widget, event
    # Setting parameter for Segmentation
    global threshold_gray = get_gtk_property(thresholdGreyscaleEntry, :text, String)
    global threshold_marker = get_gtk_property(thresholdMarkersEntry, :text, String)
    if (threshold_gray == "" || threshold_marker == "")
        run(thresholdErrorMessage)
    else
        set_gtk_property!(thresholdGreyscaleValueLabel, :label,
                        "Selected Greyscale Filter's Threshold : " * threshold_gray)
        set_gtk_property!(thresholdMarkersValueLabel, :label,
                        "Selected Marker's Distance Threshold : " * threshold_marker)
        global threshold_gray = parse(Float64, threshold_gray)
        global threshold_marker = parse(Float64, threshold_marker)
        hide(thresholdDialog)
        Gtk.set_gtk_property!(simulationButton, :sensitive, true)
    end
end

signal_connect(defaultSettingsButton, "button-press-event") do widget, event
    global threshold_gray = "0.15"
    global threshold_marker = "-0.3"
    set_gtk_property!(thresholdGreyscaleValueLabel, :label,
                    "Selected Greyscale Filter's Threshold : " * threshold_gray)
    set_gtk_property!(thresholdMarkersValueLabel, :label,
                    "Selected Marker's Distance Threshold : " * threshold_marker)
    global threshold_gray = parse(Float64, threshold_gray)
    global threshold_marker = parse(Float64, threshold_marker)
    hide(thresholdDialog)
end

# invalidThresholdMessage element
signal_connect(thresholdErrorCancelButton, "button-press-event") do widget, event
    hide(thresholdErrorMessage)
end
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
       set_gtk_property!(simulationButton, :sensitive, false)
       set_gtk_property!(thresholdGreyscaleValueLabel, :label,
                       "Selected Greyscale Filter's Threshold : _____")
       set_gtk_property!(thresholdMarkersValueLabel, :label,
                       "Selected Marker's Distance Threshold : _____")
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
    run(thresholdDialog)
    # Launch JHistint Segmentation
    JHistint.start_segmentation_SOPHYSM(filepath_slide_to_segment,
                                        filepath_slide_to_segment,
                                        threshold_gray,
                                        threshold_marker)
    set_gtk_property!(segmentedImage, :file,
                          replace(filepath_slide_to_segment,
                                  r"....$" => "_seg-0.png"))
    Gtk.set_gtk_property!(simulationButton, :sensitive, true)
end

signal_connect(simulationButton, "button-press-event") do widget, event
    filepath_file_JSPACE = replace(filepath_slide_to_segment,
                                   r"....$" => "_Files_JSpace")
    if !isdir(filepath_file_JSPACE)
        mkdir(filepath_file_JSPACE)
    end
    filepath_plot_JSPACE = replace(filepath_slide_to_segment,
                                   r"....$" => "_Plots_JSpace")
    if |isdir(filepath_plot_JSPACE)
        mkdir(filepath_plot_JSPACE)
    end
    filepath_reference_JSPACE =
        replace(filepath_slide_to_segment,
                r"....$" => "_reference.fasta")
    filepath_matrix =
        replace(filepath_slide_to_segment,
                r"....$" => ".txt")
    filepath_dataframe_labels =
        replace(filepath_slide_to_segment,
                r"....$" => "_dataframe_labels.csv")
    filepath_dataframe_edges =
        replace(filepath_slide_to_segment,
                r"....$" => "_dataframe_edges.csv")
    # Launch J-Space Simulation
    Start_J_Space(filepath_reference_JSPACE,
                    filepath_matrix,
                    filepath_file_JSPACE,
                    filepath_plot_JSPACE,
                    slide_name,
                    filepath_dataframe_edges,
                    filepath_dataframe_labels)
end

showall(mainWindow)

### end of file -- SOPHYSM_app.jl
