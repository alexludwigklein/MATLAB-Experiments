# MATLAB-Experiments
Collection of files and classes describing the outcome of an experiment with support for many builtin data types as well as custom classes, e.g. [Videos](https://github.com/alexludwigklein/MATLAB-Videos) and [BeamProfiles](https://github.com/alexludwigklein/MATLAB-BeamProfiles)

## Installation
Add the parent directory that holds all @-folders to you local MATLAB path. This task can easily be done
	with MATLAB's addpath and genpath functions. The code requires the following toolboxes to be installed 
	(depending on the features used in the [Videos](https://github.com/alexludwigklein/MATLAB-Videos) class:

* Optimization Toolbox
* Signal Processing Toolbox
* Image Processing Toolbox
* Statistics and Machine Learning Toolbox
* Curve Fitting Toolbox
* Computer Vision System Toolbox
	
Furthermore, the code makes use of some additional third party tools that can be found on the [file exchange](https://nl.mathworks.com/matlabcentral/fileexchange) or on [GitHub](https://github.com):

* [TIFFSTack](https://nl.mathworks.com/matlabcentral/fileexchange/32025-dylanmuir-tiffstack) for reading and mapping TIF files to memory
* [DataHash](https://nl.mathworks.com/matlabcentral/fileexchange/31272-datahash) for creating hash values
* [GetFullPath](https://nl.mathworks.com/matlabcentral/fileexchange/28249-getfullpath) that should be available as `fullpath` on your MATLAB path to determine the full path of a file
* [saveastiff](https://nl.mathworks.com/matlabcentral/fileexchange/35684-save-and-load-a-multiframe-tiff-image) for saving TIF files
* [export_fig](https://nl.mathworks.com/matlabcentral/fileexchange/23629-export-fig) for exporting MATLAB figures in high resolution (used when exporting videos as shown on screen)
* [SLM Tools](https://nl.mathworks.com/matlabcentral/fileexchange/24443-slm-shape-language-modeling) for Shape Language Modeling (SLM)

## Usage
A description is currently not (yet) available