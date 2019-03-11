### to generate suitable csv file from isochrone_cb.dat files
# cd to glue dir, start python, run:
import convert_iso_file as cif
cif.iso_to_csv([0,1,2,3,4,5,6], isodir='/Users/troyraen/Osiris/isomy')
# cd TO DIR CONTAINING isochrones.csv
# or MAKE SURE DATA IS ON LOCAL MACHINE.
# DOWNLOAD IF NECESSARY (i.e. if isodir is not local).

# start glue:

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

# http://docs.glueviz.org/en/stable/api/glue.viewers.scatter.state.ScatterLayerState.html
so_cb = OD([('cmap_mode', 'Linear'), ('cmap',plt.get_cmap(name='Dark2')), \
             ('cmap_att', isos.id['cboost']), ('cmap_vmin',0), ('cmap_vmax',7), ('alpha', 1) ])
so_peep = OD([('cmap_mode', 'Linear'), ('cmap',plt.get_cmap(name='Dark2')), \
             ('cmap_att', isos.id['PrimaryEEP']), ('cmap_vmin',-1), ('cmap_vmax',6), ('alpha', 1), \
             ('size_mode','Linear'), ('size_att', isos.id['PrimaryEEP']), \
             ('size_vmin',-1), ('size_vmax',20) ])
so_peepcb = OD([('cmap_mode', 'Linear'), ('cmap',plt.get_cmap(name='Dark2')), \
             ('cmap_att', isos.id['cboost']), ('cmap_vmin',0), ('cmap_vmax',7), ('alpha', 1), \
             ('size_mode','Linear'), ('size_att', isos.id['PrimaryEEP']), \
             ('size_vmin',-2), ('size_vmax',7) ])
so_mark3 = OD([ ('points_mode','markers'), ('size',3), ('alpha',1) ])
so_mark10 = OD([ ('points_mode','markers'), ('size',10), ('alpha',1) ])
###



# descriptive plots
gplots.scat(['initial_mass','log10_isochrone_age_yr'], title='Dotter Fig 1', state_options=so_peep)
gplots.scat(['log10_isochrone_age_yr', 'cboost'], title='age v cboost', \
            state_options=so_mark10)
gplots.scat(['initial_mass', 'cboost'], title='mass v cboost', \
            state_options=so_peep)
gplots.scat(['PrimaryEEP', 'cboost'], title='Primary EEP v cboost')
gplots.scat(['log10_isochrone_age_yr','center_h1'], title='ave v center_h1', state_options=so_cb)
gplots.scat(['initial_mass','center_h1'], title='initial_mass v center_h1', state_options=so_cb)
gplots.scat(['initial_mass','log10_isochrone_age_yr'], title='Dotter Fig 1', state_options=so_peep)
gplots.scat(['EEP','cboost'], title='EEP vs cboost', state_options=so_cb)
gplots.scat(['PrimaryEEP','center_h1'], title='PrimaryEEP v center_h1', state_options=so_cb)


gplots.HR(state_options=so_cb)
log(T$_{eff}$)
log(L [L$_{\odot}$])
log(Isochrone Age [yrs]) = 9.9
