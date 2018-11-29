### to generate suitable csv file from isochrone_cb.dat files
# cd to glue dir, start python, run:
import convert_iso_file as cif
cif.iso_to_csv([0,3,4,5,6])
# then start glue:

### must run in Ipython terminal after loading:
# import sys
import matplotlib.pyplot as plt
from glue.app.qt.application import GlueApplication
# dc = sys.argv[1]
ga = GlueApplication(dc)
ga.start()

# load data
dclist = ld.load_ISO(dc, ga)
dcall, isos = dclist


# load modules that depend on dclist
# import data.mysubsets as myss
# from data.mysubsets import make_subsets as makess
import layers as pl
import genplots as gplots

so_cb = OD([('cmap_mode', 'Linear'), ('cmap',plt.get_cmap(name='Dark2')), \
             ('cmap_att', isos.id['cboost']), ('cmap_vmin',0), ('cmap_vmax',7), ('alpha', 1) ])
so_mark3 = OD([ ('points_mode','markers'), ('size',3), ('alpha',1) ])
so_mark10 = OD([ ('points_mode','markers'), ('size',10), ('alpha',1) ])

# descriptive plots
gplots.scat(['log10_isochrone_age_yr', 'cboost'], title='age v cboost', \
            state_options=so_mark10)
gplots.scat(['log10_isochrone_age_yr', 'initial_mass'], title='age v mass', \
            state_options=so_so_mark3)

gplots.HR(state_options=so_cb)
log(T$_{eff}$)
log(L [L$_{\odot}$])
log(Isochrone Age [yrs]) = 9.9
