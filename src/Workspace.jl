### Includes the logic to save and update the current workspace
### the user is using.

### Exported functions
export set_workspace_dir, get_workspace_dir

# Function to get the default documents folder based on the operating system
function default_documents_folder()
    return joinpath(homedir(), "Documents")
end


function set_workspace_dir(new_workspace_dir::AbstractString)
    settings_file = joinpath(@__DIR__, "settings.json")
    settings = Dict("workspace_dir" => new_workspace_dir)

    if !isfile(settings_file)
        touch(settings_file)
    end

    open(settings_file, "w") do file
        JSON.print(file, settings)
    end

end

# Function to load or set the workspace directory
function get_workspace_dir()
    settings_file = joinpath(@__DIR__, "settings.json")
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
