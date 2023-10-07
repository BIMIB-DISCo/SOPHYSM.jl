### -*- Mode: Julia -*-

### SOPHYSM - SOlid tumors PHYlogenetic Spatial Modeller.
### SOPHYSM_app.jl

### Packages
using Gtk
# using JHistint
# using J_Space

### Data from SOPHYSM.glade
SOPHYSM_app = Gtk.GtkBuilder(filename = "SOPHYSM_FIX.glade")
mainWindow = SOPHYSM_app["mainWindow"]

###  LISTENER
## Start GUI
# Gtk.set_gtk_property!(mainWindow, :sensitive, false)
global workspace_path = Gtk.open_dialog("SOPHYSM - Select Workspace Folder",
               action= Gtk.GtkFileChooserAction.SELECT_FOLDER)
if(workspace_path != "")
    # set-visible for Gtk Crash
    # Gtk.set_gtk_property!(mainWindow, :visible, true)
    # Gtk.set_gtk_property!(mainWindow, :sensitive, true)
    showall(mainWindow)
else
    Gtk.hide(mainWindow)
end
### end of file -- SOPHYSM_app.jl
