# SOPHYSM
SOPHYSM - SOlid tumors PHYlogentic Spatial Modeller

SOPHYSM is a software for spatial phylogenetic modeling of solid tumors. It integrates image-processing functionalities for the segmentation of histological slides, allowing the extraction of spatial and morphological information from microscopic images, thereby providing a better understanding of tumor architecture and cellular interactions in space. The analysis derived from the slides provides valuable input for spatial and phylogenetic simulations. Firstly, the software simulates the spatial dynamics of the cells as a continuous-time multi-type birth-death stochastic process on a graph employing different rules of interaction and an optimized Gillespie algorithm. After mimicking a spatial sampling of the tumor cells, SOPHYSM returns the phylogenetic tree of the sample and simulates the molecular evolution of the genome under the infinite-site models or a set of different substitution models. There is also the possibility to include indels. Finally, employing ART, SOPHYSM generates the synthetic single-end, paired-/mate-pair end reads of the next-generation sequencing platforms.
The image-processing and segmentation process is provided by the Julia package JHistint available at the following GitHub repository :
The simulation of the spatial growth and the genomic evolution of the cell population and the experiment of sequencing the genome of the sampled cells is provided by the Julia package J-Space available at the following GitHub repository :







