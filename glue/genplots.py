import inspect
from collections import OrderedDict as OD
import matplotlib.pyplot as plt

# from glue.core.util import colorize_subsets
# from glue.config import viewer_tool
from glue.viewers.scatter.qt import ScatterViewer
from glue.viewers.histogram.qt import HistogramViewer

from config import gfncs, big, small
from load_mydata import dclist, gapp
import layers as pl


########### HR plot viewer
def HR(layers_to_show=['isochrones'], state_options='default', vsize=big):
    """
    LAYERS_TO_SHOW can be dict of subsets' states (eg ss_cb) or a list of subset state names
    STATE_OPTIONS = OD([ attribute, value ]) for the layer state, from
        http://docs.glueviz.org/en/stable/api/glue.viewers.scatter.state.ScatterLayerState.html
    """
    dc, isos = dclist
    lts = layers_to_show
    so = state_options
    phr = gapp.new_data_viewer(ScatterViewer)
    phr.LABEL = 'HR'
    phr.position=(0,50)
    phr.viewer_size = vsize

    phr.add_data(isos)
    st = phr.state
    st.x_att = isos.id['log_Teff']
    st.y_att = isos.id['log_L']
    st.flip_x()

    if so == 'default': #so = OD([ ('size',3) ])
        so = OD([ ('cmap_mode','Fixed'), ('points_mode','markers'), ('size',3), ('alpha',1.0) \
                ])
    pl.show_layers(st, lts, so, clear=True)

    ax=phr.axes
    ax.set_title('HR')
    ax.set_xlabel('log(T$_{eff}$)')
    ax.set_ylabel('log(L)')
    plt.tight_layout()
    ax.figure.canvas.draw()  # update the plot

    return phr
gfncs['HR']= {'name':'HR', \
        'Signature':inspect.signature(HR), \
        'Docstring':inspect.getdoc(HR), \
        'class':'plot'}




############# General Scatter Viewer
def scat(ax_attr, data_set='isochrones', layers_to_show='default', \
        state_options='default', vsize=big, title='Scatter', hline=None, vline=None):
    """
    AX_ATTR = ['x_att', 'y_att']
    DATA_SET: one of 'historyDF', 'profileDF', or 'descDF'
    LAYERS_TO_SHOW: one of dict of subsets' states (eg ss_cb) or list of subset state names
    STATE_OPTIONS = OD([ attribute, value ]) for the layer state, from
        http://docs.glueviz.org/en/stable/api/glue.viewers.scatter.state.ScatterLayerState.html
    VSIZE: one of 'big', 'small', or (length, height)
    TITLE: 'plot title'
    HLINE, VLINE: if number give, draw line on plot
    """
    dc, isos = dclist
    xatt, yatt = ax_attr
    ds = data_set
    lts = layers_to_show
    if lts == 'default': lts=[ds]
    so = state_options

    pscat = gapp.new_data_viewer(ScatterViewer)
    pscat.LABEL = title
    # pscat.position=(0,50)
    pscat.viewer_size = vsize
    pscat.position=(210,120)
    st = pscat.state

    # plot, depending on data_set
    if ds == 'isochrones':
        pscat.add_data(isos)
        st.x_att = isos.id[xatt]
        st.y_att = isos.id[yatt]

    else:
        print('No data_set called', ds)
        return

    if so == 'default': so = OD([ ('cmap_mode','Fixed'), ('alpha',1.0), \
            ('dpi',14) ])
    pl.show_layers(st, lts, so, clear=True)

    ax=pscat.axes
    ax.set_title(title)
    if hline is not None:
        ax.axhline(hline)
    if vline is not None:
        ax.axvline(vline)
    plt.tight_layout()
    ax.figure.canvas.draw()  # update the plot

    return pscat
gfncs['scat']= {'name':'scat', \
        'Signature':inspect.signature(scat), \
        'Docstring':inspect.getdoc(scat), \
        'class':'plot'}




############# General Histogram Viewer
def hist(x_attr, data_set='historyDF', layers_to_show='default', \
        state_options='default', vsize=big, title='Histogram'):
    """
    X_ATTR = 'x_att'
    DATA_SET: one of 'historyDF', 'profileDF', or 'descDF'
    LAYERS_TO_SHOW: one of dict of subsets' states (eg ss_cb) or list of subset state names
    STATE_OPTIONS = OD([ attribute, value ]) for the layer state, from
        http://docs.glueviz.org/en/stable/api/glue.viewers.Histogram.state.HistogramLayerState.html
    VSIZE: one of 'big', 'small', or (length, height)
    TITLE: 'plot title'
    """
    dc, isos = dclist
    xatt = x_attr
    ds = data_set
    lts = layers_to_show
    if lts == 'default': lts=[ds]
    so = state_options

    phist = gapp.new_data_viewer(HistogramViewer)
    phist.LABEL = title
    # phist.position=(0,50)
    phist.viewer_size = vsize
    st = phist.state

    # plot, depending on data_set
    if ds == 'historyDF':
        phist.add_data(history)
        st.x_att = history.id[xatt]

    elif ds == 'profilesDF':
        phist.add_data(profiles)
        st.x_att = profiles.id[xatt]

    elif ds == 'descDF':
        phist.add_data(desc)
        st.x_att = desc.id[xatt]

    else:
        print('No data_set called', ds)
        return

    if so == 'default': so = OD([ ('cmap_mode','Fixed'), ('alpha',1.0), \
            ('dpi',4) ])
    pl.show_layers(st, lts, so, clear=True)

    ax=phist.axes
    ax.set_title(title)
    plt.tight_layout()
    ax.figure.canvas.draw()  # update the plot

    return phist
gfncs['hist']= {'name':'hist', \
        'Signature':inspect.signature(hist), \
        'Docstring':inspect.getdoc(hist), \
        'class':'plot'}
