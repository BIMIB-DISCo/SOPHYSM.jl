### SOPHYSM-- SOlid tumors PHYlogentic Spatial Modeller
### SOPHYSM.jl

module SOPHYSM

### Packages
using QML
using Observables
using JSON
using JHistint

### Included modules
include("Workspace.jl")
include("SOPHYSMLogger.jl")
include("imaging/Net.jl")

### Exported functions
export start_GUI

### Constants
workspace_dir = Observable(Workspace.get_workspace_dir())
selected_image_path = Observable("")
segmentation_update_text = Observable("{...}")

### Main Functions

function UNet_Segmentation(img_path::AbstractString)
    if(isempty(img_path))
        s_log_message("@error", "Img path not selected")
    else
        segmentation_update_text = Observable("Starting segmentation...")
        s_log_message("@info", "Correct input image given at " * img_path)
        # model = load_model("/home/moeasy/github/SOPHYSM/best_model.bson")
    # ...
    end
end


### GUI logic
function start_GUI()
    s_open_logger()
    s_log_message("@info", "Start GUI")

    workspace_dir = Observable(Workspace.get_workspace_dir())
    Workspace.set_environment()
    selected_image_path = Observable("")

    qmlfile = joinpath(@__DIR__, "qml", "SOPHYSM.qml")

    ### QML Functions
    qmlfunction("download_single_slide_from_collection", async_download_single_slide_from_collection)
    qmlfunction("log_message", s_log_message)
    qmlfunction("display_img", Workspace.display_img)
    qmlfunction("UNet_Segmentation", UNet_Segmentation)
    
    # Propmap
    propmap = JuliaPropertyMap()
    propmap["workspace_dir"] = workspace_dir
    propmap["selected_image_path"] = selected_image_path
    propmap["segmentation_update_text"] = segmentation_update_text

    # Listening if there is any changes on workspace_dir
    on(workspace_dir) do x
        Workspace.set_workspace_dir(x)
        workspace_dir = Observable(Workspace.get_workspace_dir())
        s_log_message("@info", "WS Changed to $workspace_dir")
    end

    # Listening if there is any changes on the image the user selected
    on(selected_image_path) do x
        selected_image_path = x
    end

    # All keyword arguments to load are added as context properties on the QML side
    loadqml(qmlfile, propmap = propmap)
    
    exec_async()

    s_log_message("@info", "Close GUI")
    s_close_logger()
end

end # SOPHYSM module
