# SOPHYSM - SOlid tumors PHYlogentic Spatial Modeller
SOPHYSM is a software for spatial phylogenetic modeling of solid tumors. It integrates image-processing functionalities for the segmentation of histological slides, allowing the extraction of spatial and morphological information from microscopic images, thereby providing a better understanding of tumor architecture and cellular interactions in space. The analysis derived from the slides provides valuable input for spatial and phylogenetic simulations. Firstly, the software simulates the spatial dynamics of the cells as a continuous-time multi-type birth-death stochastic process on a graph employing different rules of interaction and an optimized Gillespie algorithm. After mimicking a spatial sampling of the tumor cells, SOPHYSM returns the phylogenetic tree of the sample and simulates the molecular evolution of the genome under the infinite-site models or a set of different substitution models. There is also the possibility to include indels.

## Resources
- The image-processing pipeline and segmentation algorithm is provided by the Julia package `JHistint.jl` available at the following GitHub repository: [JHistint Repository](https://github.com/niccolo99mandelli/JHistint.jl.git).  
- The simulation of the spatial growth and the genomic evolution of the cell population and the experiment of sequencing the genome of the sampled cells is provided by the Julia package `J-Space.jl` available at the following GitHub repository at the `spatial-input` branch: [J-Space Repository](https://github.com/BIMIB-DISCo/J-Space.jl).  

## Usage
The software provides a graphical user interface (GUI) in Julia is designed to facilitate the management of projects related to histological analysis and spatial cancer simulation. It offers a comprehensive set of features to streamline the handling of workspace and dedicated projects that store information and results associated with various case studies. The GUI provides a user-friendly interface to build workspace where you can create and manage projects, each dedicated to a specific case study. Projects serve as containers for storing data and results related to histological analysis and cancer spatial simulation.
The interface provides functionalities to upload histological slides to be segmented. Users can define configuration parameters for histological analysis, allowing for tailored and precise image processing. Image segmentation is a core feature, enabling users to extract meaningful regions of interest from uploaded images as cell or nuclei. For further information consults: [Julia Images Documentation - Watershed algorithm](https://juliaimages.org/v0.21/imagesegmentation/).

In order to optimize the output of the segmentation, users can define a set of configuration parameters:
- `Grayscale-threshold`: Used to define the cutoff threshold for regions determined by the watershed algorithm.
- `Marker-Distance threshold`: Used to determine the maximum distance for generating markers related to nuclei or cells.
- `Minimum-noise threshold`: Used to establish the minimum threshold at which all areas with a surface area smaller than the threshold are eliminated and not considered for defining nuclei or cells.
- `Maximum-noise threshold`: Used to define the maximum threshold at which all areas with a surface area larger than the threshold are associated with nuclei or cells.

Image segmentation can be performed in two modes:
- `Graph-Based Segmentation`: This mode involves constructing an adjacency graph and its corresponding matrix using the powerful `JuliaImages` package (`imagesegmentation.jl`). This approach helps identify interconnections within the cell or nuclei.
- `Tessellation-Based Segmentation`: Users can create tessellations, optimizing spatial input according to the simulator's requirements, effectively partitioning the image for further analysis connected to spatial dynamics.

Once segmentation is complete, the simulation can be initiated to study the spatial distribution of cancerous elements. The results of the simulation are visualized, and users can explore them in a separate window. The Julia REPL terminal will provide tracking of the simulation steps. The GUI also provides capabilities for downloading a database of histological images. Image database management features can be accessed conveniently through the navigation bar. Users can define the collection of data to be downloaded in base of the cancer type.

<table align="center">
    <tr>
      <td align="center">
        <img src="docs/sophysm_workspace.PNG" alt="Selecting workspace">
        <br>
        Select workspace Menu
      </td>
    </tr>
    <tr>
      <td align="center">
        <img src="docs/sophysm_newproject.PNG" alt="New Project">
        <br>
        New Project Dialog
      </td>
    </tr>
    <tr>
      <td align="center">
        <img src="docs/sophysm_main.PNG" alt="Main Window">
        <br>
        Main Window SOPHYSM
      </td>
    </tr>
    <tr>
      <td align="center">
        <img src="docs/sophysm_config.PNG" alt="Configuration Parameters">
        <br>
         Dialog for Segmentation Parameters
      </td>
    </tr>
    <tr>
      <td align="center">
        <img src="docs/sophysm_graph1.PNG" alt="Main Window - Segmentation Results">
        <br>
        Main Window SOPHYSM - Segmentation Results
      </td>
    </tr>
    <tr>
      <td align="center">
        <img src="docs/sophysm_tessellation.PNG" alt="Main Window - Tessellation Results">
        <br>
        Main Window SOPHYSM - Tessellation Results
      </td>
    </tr>
    <tr>
      <td align="center">
        <img src="docs/sophysm_finalt.PNG" alt="Simulation Window - Spatial Dynamic Result">
        <br>
        Simulation Window - Spatial Dynamic Result
      </td>
    </tr>
    <tr>
      <td align="center">
        <img src="docs/sophysm_drivertree.PNG" alt="Simulation Window - Driver Tree">
        <br>
        Simulation Window - Driver Tree
      </td>
    </tr>
    <tr>
      <td align="center">
        <img src="docs/sophysm_phylotree.PNG" alt="Simulation Window - Phylogenetic Tree">
        <br>
        Simulation Window - Phylogenetic Tree
      </td>
    </tr>
    <tr>
      <td align="center">
        <img src="docs/sophysm_collection.PNG" alt="Database Collection - Choose Collection Dialog">
        <br>
        Database Collection - Choose Collection Dialog
      </td>
    </tr>
 </table>

## Installation
