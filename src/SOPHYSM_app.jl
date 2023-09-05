### -*- Mode: Julia -*-

### SOPHYSM - SOlid tumors PHYlogenetic Spatial Modeller.
### SOPHYSM_app.jl

### Packages
using Gtk
# using JHistint
# using J_Space

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
jspaceOutputDialog = SOPHYSM_app["jspaceOutputDialog"]
## menuBar
menuBar = SOPHYSM_app["menuBar"]
newProjectMenuItem = SOPHYSM_app["newProjectMenuItem"]
loadProjectMenuItem = SOPHYSM_app["loadProjectMenuItem"]
closeProjectMenuItem = SOPHYSM_app["closeProjectMenuItem"]
quitMenuItem = SOPHYSM_app["quitMenuItem"]
loadImageMenuItem = SOPHYSM_app["loadImageMenuItem"]
downloadSingleCollectionMenuItem = SOPHYSM_app["downloadSingleCollectionMenuItem"]
downloadAllCollectionMenuItem = SOPHYSM_app["downloadAllCollectionMenuItem"]
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
## jspaceOutputDialog
conf10PlotButton = SOPHYSM_app["conf10PlotButton"]
conf20PlotButton = SOPHYSM_app["conf20PlotButton"]
confFinalPlotButton = SOPHYSM_app["confFinalPlotButton"]
driverTreeButton = SOPHYSM_app["driverTreeButton"]
outputPlotImage = SOPHYSM_app["outputPlotImage"]
jspaceOutputCloseButton = SOPHYSM_app["jspaceOutputCloseButton"]
## Variables
path_project_folder = ""
path_slide_folder = ""
filepath_slide_to_segment = ""
filepath_slide = ""
project_name = ""
slide_name = ""
threshold_gray = ""
threshold_marker = ""
collection_name = ""

# Variables Output J-Space
filepath_file_JSPACE = ""
filepath_plot_JSPACE = ""
filepath_reference_JSPACE = ""
filepath_matrix = ""
filepath_dataframe_labels = ""
filepath_dataframe_edges = ""

###  LISTENER
## menuBar elements
signal_connect(newProjectMenuItem, "button-press-event") do widget, event
    run(newProjectDialog)
end

signal_connect(loadProjectMenuItem, "button-press-event") do widget, event
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
        set_gtk_property!(loadImageMenuItem, :sensitive, true)
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

signal_connect(closeProjectMenuItem, "button-press-event") do widget, event
    set_gtk_property!(loadButton, :sensitive, false)
    set_gtk_property!(loadImageMenuItem, :sensitive, false)
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

signal_connect(quitMenuItem, "button-press-event") do widget, event
    hide(mainWindow)
    hide(thresholdDialog)
    hide(newProjectDialog)
    hide(projectAlreadyExistMessage)
    hide(invalidNameProjectMessage)
    hide(slideAlreadyExistMessage)
    hide(thresholdErrorMessage)
    hide(chooseCollectionDialog)
end

signal_connect(loadImageMenuItem, "button-press-event") do widget, event
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

signal_connect(downloadSingleCollectionMenuItem, "button-press-event") do widget, event
    run(chooseCollectionDialog)
end

signal_connect(downloadAllCollectionMenuItem, "button-press-event") do widget, event
    path_download_dataset =
        open_dialog("SOPHYSM - Select Folder for Downloading Dataset",
                    action=GtkFileChooserAction.SELECT_FOLDER)
    # Call JHistInt
    ### JHistint.download_all_collection()
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
    ### SHOW PREVIOUS ANALYSIS
end
## newProjectDialog elements
signal_connect(newProjectDialog, "delete-event") do widget, event
    hide(newProjectDialog)
end

signal_connect(newProjectOkButton, "button-press-event") do widget, event
    global project_name = get_gtk_property(projectNameEntry, :text, String)
    global path_project_folder = joinpath(workspace_path, project_name)
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
            set_gtk_property!(loadImageMenuItem, :sensitive, true)
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
    global collection_name = get_gtk_property(nameCollectionEntry, :text, String)
    path_download_dataset =
        open_dialog("SOPHYSM - Select Folder for Downloading Dataset",
                    action=GtkFileChooserAction.SELECT_FOLDER)
    # Call JHistInt
    ### JHistint.download_single_collection(collection_name)
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
    set_gtk_property!(thresholdGreyscaleEntry, :text, "0.15")
    set_gtk_property!(thresholdMarkersEntry, :text, "-0.3")
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
end

signal_connect(simulationButton, "button-press-event") do widget, event
    global filepath_file_JSPACE = replace(filepath_slide_to_segment,
                                   r"....$" => "_Files_JSpace")
    if !isdir(filepath_file_JSPACE)
        mkdir(filepath_file_JSPACE)
    end
    global filepath_plot_JSPACE = replace(filepath_slide_to_segment,
                                   r"....$" => "_Plots_JSpace")
    if !isdir(filepath_plot_JSPACE)
        mkdir(filepath_plot_JSPACE)
    end
    global filepath_reference_JSPACE =
        replace(filepath_slide_to_segment,
                r"....$" => "_reference.fasta")
    global filepath_matrix =
        replace(filepath_slide_to_segment,
                r"....$" => ".txt")
    global filepath_dataframe_labels =
        replace(filepath_slide_to_segment,
                r"....$" => "_dataframe_labels.csv")
    global filepath_dataframe_edges =
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
    run(jspaceOutputDialog)
end

## jspaceOutputDialog elements
signal_connect(conf10PlotButton, "button-press-event") do widget, event
    filepath_conf10Plot = joinpath(filepath_plot_JSPACE, "Conf_t_10.png")
    set_gtk_property!(outputPlotImage, :file, filepath_conf10Plot)
end

signal_connect(conf20PlotButton, "button-press-event") do widget, event
    filepath_conf20Plot = joinpath(filepath_plot_JSPACE, "Conf_t_20.png")
    set_gtk_property!(outputPlotImage, :file, filepath_conf20Plot)
end

signal_connect(confFinalPlotButton, "button-press-event") do widget, event
    filepath_confFinalPlot = joinpath(filepath_plot_JSPACE, "Final_conf.png")
    set_gtk_property!(outputPlotImage, :file, filepath_confFinalPlot)
end

signal_connect(driverTreeButton, "button-press-event") do widget, event
    filepath_driverTree = joinpath(filepath_plot_JSPACE, "driver_tree.png")
    set_gtk_property!(outputPlotImage, :file, filepath_driverTree)
end

signal_connect(jspaceOutputCloseButton, "button-press-event") do widget, event
    hide(jspaceOutputDialog)
end

## Start GUI
workspace_path = open_dialog("SOPHYSM - Select Workspace Folder",
                action=GtkFileChooserAction.SELECT_FOLDER)
if(workspace_path != "")
    set_gtk_property!(menuBar, :sensitive, true)
    set_gtk_property!(mainWindow, :sensitive, true)
    showall(mainWindow)
else
    hide(mainWindow)
end

### end of file -- SOPHYSM_app.jl
