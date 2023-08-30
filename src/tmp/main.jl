# SOPHYSM - SOlid tumors PHYlogentic Spatial Modeller
using Gtk
using JHistint
using J_Space

function create_gui()
    # function listener for loadButton
    function loadButton_clicked_callback(widget)
        Gtk.set_gtk_property!(segmentationButton, :sensitive, true)
        Gtk.set_gtk_property!(simulationButton, :sensitive, false)
        filepath_slide = open_dialog("Pick an histological slide file", GtkNullContainer(), ("*.tif", "*.png", "*.jpg", GtkFileFilter("*.tif, *.png, *.jpg", name="All supported formats")))
        Gtk.set_gtk_property!(selected_slide, :file, filepath_slide)
        Gtk.set_gtk_property!(segmented_slide, :file, "")
        filepath_to_segment = filepath_slide
    end

    # function listener for segmentationButton (Output JHistInt)
    function segmentationButton_clicked_callback(widget)
        Gtk.set_gtk_property!(simulationButton, :sensitive, true)

        # setting parameter for segmentation
        threshold_gray = get_gtk_property(thresholdGray_entry, :text, String)
        threshold_marker = get_gtk_property(thresholdMarker_entry, :text, String)
        if(threshold_gray == "")
            threshold_gray = 0.15
        else
            threshold_gray = parse(Float64, threshold_gray)
        end
        if(threshold_marker == "")
            threshold_marker = -0.3
        else
            threshold_marker = parse(Float64, threshold_marker)
        end

        # setting filepath and directory for JHistint output files
        if Sys.iswindows()
            res = split(filepath_to_segment, "\\")
        elseif Sys.islinux()
            res = split(filepath_to_segment, "/")
        end
        data = []
        for i in res
            push!(data, i)
        end
        filename = data[end]
        build_dir = joinpath(@__DIR__, "..", "output_files", filename)
        build_dir = replace(build_dir, r"....$" => "_output")
        if isdir(build_dir)
            # do nothing
        else
            mkdir(build_dir) # create directory for saving J_Space files
        end
        filepath_output = joinpath(build_dir, filename)

        # Interface with JHistint for segmentation
        JHistint.start_segmentation_SOPHYSM(filepath_to_segment, filepath_output, threshold_gray, threshold_marker)

        # load Segmented Slide in GUI
        Gtk.set_gtk_property!(segmented_slide, :file, replace(filepath_output, r"....$" => "_seg-0.png"))
    end

    # function listener for simulationButton (Output J-Space)
    function simulationButton_clicked_callback(widget)
        # setting filepath and directory for J-Space output files
        filepath_file_JSPACE = replace(filepath_output, r"....$" => "_Files_JSpace")
        if isdir(filepath_file_JSPACE)
            # do nothing
        else
            mkdir(filepath_file_JSPACE) # create directory for saving J_Space files
        end

        filepath_plot_JSPACE = replace(filepath_output, r"....$" => "_Plots_JSpace")
        if isdir(filepath_plot_JSPACE)
            # do nothing
        else
            mkdir(filepath_plot_JSPACE) # create directory for saving J_Space plots
        end
        filepath_reference_JSPACE = replace(filepath_output, r"....$" => "_reference.fasta")
        filepath_matrix = replace(filepath_output, r"....$" => ".txt")
        filepath_dataframe_labels = replace(filepath_output, r"....$" => "_dataframe_labels.csv")
        filepath_dataframe_edges = replace(filepath_output, r"....$" => "_dataframe_edges.csv")

        # Interface with J-Space for simulation
        Start_J_Space(filepath_reference_JSPACE,
                        filepath_matrix,
                        filepath_file_JSPACE,
                        filepath_plot_JSPACE,
                        filename,
                        filepath_dataframe_edges,
                        filepath_dataframe_labels)

        # load result in GUI
        gbox3 = GtkGrid()
        Conf_t_10 = Gtk.Image()
        Conf_t_20 = Gtk.Image()
        Final_conf = Gtk.Image()
        driver_tree = Gtk.Image()
        Gtk.set_gtk_property!(Conf_t_10, :file, joinpath(filepath_plot_JSPACE, "Conf_t_10.png"))
        Gtk.set_gtk_property!(Conf_t_20, :file, joinpath(filepath_plot_JSPACE, "Conf_t_20.png"))
        Gtk.set_gtk_property!(Final_conf, :file, joinpath(filepath_plot_JSPACE, "Final_conf.png"))
        Gtk.set_gtk_property!(driver_tree, :file, joinpath(filepath_plot_JSPACE, "driver_tree.png"))
        # gbox3[1,1] = Conf_t_10
        # gbox3[1,2] = Conf_t_20
        gbox3[1,1] = Final_conf
        gbox3[2,1] = driver_tree
        # FIX ART SIMULATOR OUTPUT

        # window setting
        Gtk.set_gtk_property!(gbox3, :border_width, 5)
        Gtk.set_gtk_property!(gbox3, :column_spacing, 5)
        Gtk.set_gtk_property!(gbox3, :row_spacing, 5)
        second_window = GtkWindow("SOPHYSM - J-Space Simulator Output", 1000, 300)
        push!(second_window, gbox3)
        Gtk.set_gtk_property!(second_window, :border_width, 10)
        showall(second_window)
    end

    # MAIN WINDOW -- START
    filepath_to_segment = ""
    filepath_output = ""
    filename = ""
    # Horizontal Box
    vbox = Gtk.Box(:h, 2)
    # Grid Box
    gbox1 = GtkGrid()
    gbox2 = GtkGrid()

    # Left Box
    # Setting threshold
    thresholdGray_entry  = GtkEntry()
    thresholdMarker_entry = GtkEntry()
    Gtk.set_gtk_property!(thresholdGray_entry, :placeholder_text, "Enter the threshold for the grayscale filter... (default 0.15)")
    Gtk.set_gtk_property!(thresholdMarker_entry, :placeholder_text, "Enter the threshold to define the distance between the markers... (default -0.3)")
    Gtk.set_gtk_property!(thresholdGray_entry, :width_chars, 46)
    Gtk.set_gtk_property!(thresholdMarker_entry, :width_chars, 62)
    segmentationButton = GtkButton("Start JHistInt Segmentation")
    gbox1[1,1] = thresholdGray_entry
    gbox1[2,1] = thresholdMarker_entry
    gbox1[1:2,2] = segmentationButton
    Gtk.set_gtk_property!(segmentationButton, :sensitive, false)
    # Selected Slide
    selected_slide = GtkImage()
    gbox1[1:2,0] = selected_slide

    # Right Box
    label = GtkLabel("Output of the Segmentation Process : ")
    simulationButton = GtkButton("Start J-Space Simulation")
    # Segmented Slide
    segmented_slide = Gtk.Image()
    gbox2[1,1] = label
    gbox2[1,2] = segmented_slide
    gbox2[1,3] = simulationButton
    Gtk.set_gtk_property!(simulationButton, :sensitive, false)

    # vertical box setting
    loadButton = GtkButton("Load Histological Slide ...")
    push!(vbox, loadButton)
    push!(vbox, gbox1)
    push!(vbox, gbox2)
    Gtk.set_gtk_property!(gbox1, :border_width, 5)
    Gtk.set_gtk_property!(gbox2, :border_width, 5)
    Gtk.set_gtk_property!(gbox1, :column_spacing, 5)
    Gtk.set_gtk_property!(gbox2, :column_spacing, 5)
    Gtk.set_gtk_property!(gbox1, :row_spacing, 5)
    Gtk.set_gtk_property!(gbox2, :row_spacing, 5)

    # main window setting
    main_win = GtkWindow("SOPHYSM - SOlid tumors PHYlogentic Spatial Modeller", 1000, 300)
    Gtk.set_gtk_property!(main_win, :border_width, 10)
    push!(main_win, vbox)
    # show window
    showall(main_win)

    # Signals clicked
    id_1 = signal_connect(segmentationButton_clicked_callback, segmentationButton, "clicked")
    id_2 = signal_connect(simulationButton_clicked_callback, simulationButton, "clicked")
    id_3 = signal_connect(loadButton_clicked_callback, loadButton, "clicked")
end

# Call function to build GUI
create_gui()
