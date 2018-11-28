# python imports
import numpy as np
from collections import OrderedDict as OD
import inspect
import importlib as imp # imp.reload(mod) to reload module
from glue.config import link_function

# import sys
# # glue imports
import glue as glue
# from glue.core import DataCollection
# from glue.core import Data
# from glue.core.util import colorize_subsets
# from glue.config import viewer_tool
# from glue.viewers.scatter.qt import ScatterViewer
# from glue.viewers.common.qt.tool import CheckableTool
# from glue.viewers.common.qt.tool import Tool

# OD registry for all of my functions
gfncs = OD([])

# plot viewer sizes
big = (900,650)
small = (600,400)

# Colormaps
# options: https://matplotlib.org/examples/color/colormaps_reference.html
from glue.config import colormaps
from matplotlib.cm import Paired
colormaps.add('Paired', Paired)
from matplotlib.cm import Dark2
colormaps.add('Dark2', Dark2)
from matplotlib.cm import nipy_spectral
colormaps.add('nipy', nipy_spectral)
from matplotlib.cm import tab20
colormaps.add('nipy', tab20)

# link functions
# @link_function(info="Link 'star_index' to 'other'", output_labels=['other'])
# def sidx_to_other2(sidx):
#     other = np.asarray([i[-1] for i in sidx])
#     return other

# load data module
import load_mydata as ld
