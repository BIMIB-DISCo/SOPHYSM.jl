### Includes the logic to save and update the current user workspace
module Workspace

### Packages
using JSON
using Images
using QML
using ImageMagick

### Exported functions
export set_workspace_dir, get_workspace_dir, display_img

### Exported constants
export CONFIG_DIR, DATA_DIR

# identify the standard directories for data and resources based on the operating system
if Sys.islinux()
    # according to XDG Standards: $XDR_CONFIG_HOME
    const CONFIG_DIR = joinpath(homedir(), ".config", "SOPHYSM")
    # according to XDG Standards: $XDR_DATA_HOME is $HOME/.local/share
    # Initialize the standard Workspace directory if none has been set
    const DATA_DIR = joinpath(homedir(), ".local", "share", "SOPHYSM")

elseif Sys.iswindows()
    # Config data will be saved in %APPDATA% into Local folder
    const CONFIG_DIR = joinpath(homedir(), "AppData", "Local", "SOPHYSM")
    const DATA_DIR = CONFIG_DIR
    
elseif Sys.isapple()
    const CONFIG_DIR = joinpath(homedir(), ".config", "SOPHYSM")
    const DATA_DIR = CONFIG_DIR

# For all the other operating systems the configuration files will be saved in
# SOPHYSM.jl folder
else 
    const CONFIG_DIR = @__DIR__
    const DATA_DIR = joinpath(homedir(), "SOPHYSM")
end

# Initialize standard directories on first launch of the application
if !isdir(CONFIG_DIR) 
    mkdir(CONFIG_DIR)
end

if !isdir(DATA_DIR) 
    mkdir(DATA_DIR)
end

"""
    default_workspace_folder()

Sets the directory for the user workspace.

This function sets the directory for the user workspace and updates the configuration file accordingly.
"""
function default_workspace_folder()
    if !isdir(joinpath(DATA_DIR, "SOPHYSM-Workspace"))
        mkdir(joinpath(DATA_DIR, "SOPHYSM-Workspace"))
    end
    return joinpath(DATA_DIR, "SOPHYSM-Workspace")
end

"""
    set_workspace_dir(new_workspace_dir::AbstractString)

Sets the directory for the user workspace.

# Arguments
- `new_workspace_dir::AbstractString`: New directory path for the user workspace.

This function sets the directory for the user workspace and updates the configuration file accordingly.
"""
function set_workspace_dir(new_workspace_dir::AbstractString)
    settings_file = joinpath(CONFIG_DIR, "SOPHYSM_settings.json")

    if Sys.iswindows() && new_workspace_dir[1] == '/'
        new_workspace_dir = new_workspace_dir[2:end]
    end
    settings = Dict("workspace_dir" => new_workspace_dir)

    # create settings_file if doesn't exist
    if !isfile(settings_file)
        touch(settings_file)
    end

    open(settings_file, "w") do file
        JSON.print(file, settings)
    end
end

"""
    get_workspace_dir()

Retrieves the current directory of the user workspace.

This function retrieves the current directory of the user workspace from the configuration file.
If the workspace directory is not specified or saved in the configuration file, a default directory is used.
"""
function get_workspace_dir()
    settings_file = joinpath(CONFIG_DIR, "SOPHYSM_settings.json")
    default_workspace_dir = default_workspace_folder() 

    # If the settings file exists, load the workspace directory from there
    if isfile(settings_file)
        settings = JSON.parsefile(settings_file)
        workspace_dir = get(settings, "workspace_dir", default_workspace_dir)
    else
        workspace_dir = default_workspace_dir
        set_workspace_dir(workspace_dir)
    end

    return workspace_dir
end

"""
    set_environment()

Ensures the existence of necessary directories and initializes the workspace directory if not already set.
"""
function set_environment()
    if !isdir(CONFIG_DIR) 
        mkdir(CONFIG_DIR)
    end    
    if !isdir(DATA_DIR) 
        mkdir(DATA_DIR)
    end
    if !isfile(joinpath(CONFIG_DIR, "SOPHYSM_settings.json"))
        set_workspace_dir(default_workspace_folder())
    end
end

"""
    display(d:JuliaDisplay, path::AbstractString)

    display selected image
"""
function display_img(d::JuliaDisplay, path::AbstractString)
    img = ImageMagick.load(path; view = true)
    display(d, img)
end

end # module SOPHYSM.Workspace