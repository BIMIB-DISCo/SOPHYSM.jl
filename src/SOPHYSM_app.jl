using Gtk

SOPHYSM_app = GtkBuilder(filename = "SOPHYSM.glade")

window = SOPHYSM_app["mainWindow"]
segmentationButton = SOPHYSM_app["segmentationButton"]

function on_segmentationButton_clicked()

end

showall(window)
