import inspect
from config import gfncs


def show_layers(plotstate, subset_to_show, state_options, clear=False):
    """plotstate = viewer.state
    SUBSET_TO_SHOW can be dict of subsets' states (eg ss_cb) or a list of subset state names
    STATE_OPTIONS = OD([ attribute, value ]) for the layer state, from
        http://docs.glueviz.org/en/stable/api/glue.viewers.scatter.state.ScatterLayerState.html
    CLEAR = True will clear all other subsets from the view
    """
    st = plotstate
    ss = subset_to_show
    so = state_options

    if type(ss)==dict: ss = list(ss.keys())
    for layst in st.layers: # layst is a specific layer's state
        if layst.layer.label not in ss: # layst.layer is the data object
            if clear==True: layst.visible = False
            # continue
        else:
            layst.visible = True


        for stkey, stval in so.items():
            setattr(layst, stkey, stval)


gfncs['show_layers']= {'Signature':inspect.signature(show_layers), 'class':'plots help'}


def show_layers_allplots(subset_to_show, state_options):
    """subset_to_show can be dict of subsets (eg ss_cb) or a list of subset names (eg '1.1c2')
    state_options = dict of { attribute : value } from
    http://docs.glueviz.org/en/stable/api/glue.viewers.scatter.state.ScatterLayerState.html
    """
    ss = subset_to_show
    so = state_options

    for v in ga.viewers[0]: # for all viewers in tab 1
        print(v)
        if type(v) == glue.viewers.table.qt.data_viewer.TableViewer: continue
        st = v.state
        show_layers(st,ss,so)
gfncs['show_layers_allplots']= {'Signature':inspect.signature(show_layers_allplots), \
                                'class':'plots help'}
