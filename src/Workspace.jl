### Includes the logic to save and update the current user workspace
module Workspace

### Packages
using JSON

### Exported functions
export set_workspace_dir, get_workspace_dir

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

# initialize the standard directories on first launch of the app on the system
if !isdir(CONFIG_DIR) 
    mkdir(CONFIG_DIR)
end

if !isdir(DATA_DIR) 
    mkdir(DATA_DIR)
end

function default_workspace_folder()
    return joinpath(DATA_DIR, "SOPHYSM-Workspace")
end

function set_workspace_dir(new_workspace_dir::AbstractString)
    settings_file = joinpath(CONFIG_DIR, "SOPHYSM_settings.json")
    settings = Dict("workspace_dir" => new_workspace_dir)

    # create settings_file if doesn't exist
    if !isfile(settings_file)
        touch(settings_file)
    end

    open(settings_file, "w") do file
        JSON.print(file, settings)
    end
end

# Function to load or set the workspace directory
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

function set_environment()
    if !isfile(joinpath(CONFIG_DIR, "SOPHYSM_settings.json"))
        set_workspace_dir(default_workspace_folder())
    end
end

end # module SOPHYSM.Workspace