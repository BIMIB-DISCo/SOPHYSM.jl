### Includes the logic to save and update the current workspace
### the user is using.
module Workspace

### Packages
using JSON


### Exported functions
export set_workspace_dir, get_workspace_dir

# Function to get the default documents folder based on the operating system
if Sys.islinux()
    # according to XDG Standards: $XDR_CONFIG_HOME is $HOME/.config
    config_dir = joinpath(homedir(), ".config", "SOPHYSM")

elseif Sys.iswindows()
    # %APPDATA%
    config_dir = joinpath(homedir(), "AppData", "Roaming", "SOPHYSM")

elseif Sys.isapple()
    config_dir = joinpath(homedir(), "Library/.../SOPHYSM")
# For all the other Operating systems:

else 
    config_dir = @__DIR__
end

function default_documents_folder()
    return joinpath(homedir(), "Documents")
end


function set_workspace_dir(new_workspace_dir::AbstractString)
    settings_file = joinpath(config_dir, "SOPHYSM_settings.json")
    settings = Dict("workspace_dir" => new_workspace_dir)

    if !isfile(settings_file)
        mkdir(config_dir)
        touch(settings_file)
    end

    open(settings_file, "w") do file
        JSON.print(file, settings)
    end
end

# Function to load or set the workspace directory
function get_workspace_dir()
    settings_file = joinpath(config_dir, "SOPHYSM_settings.json")
    default_workspace_dir = default_documents_folder()

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

end # module SOPHYSM.Workspace