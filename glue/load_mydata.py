import inspect
from config import gfncs
from glue.core.data_factories import load_data
from glue.core.component_link import ComponentLink
# from glue.core import Data

dclist = []
gapp = None # placeholder for GlueApplication

# load isochrone file
def load_ISO(dc, ga) -> '[ dc, isochrones ]':
    globals()['gapp'] = ga # set ga for use later
    dc.append(load_data('historyDF.csv'))
    history = dc[0]
    dc.append(load_data('profilesDF.csv'))
    profiles = dc[1]
    dc.append(load_data('descDF.csv'))
    desc = dc[2]
    globals()['dclist'] = [ dc, history, profiles, desc ]
    return dclist
gfncs['load_HPD']= {'name':'load_HPD', \
                    'Signature':inspect.signature(load_HPD), \
                    'Docstring':inspect.getdoc(load_HPD), \
                    'class':'data'}

# link history, profiles, desc data
def link_HPD():
    dc, history, profiles, desc = dclist
    dc.add_link(ComponentLink([history.id['model_number']], profiles.id['model_number']))
    dc.add_link(ComponentLink([history.id['profile_number']], profiles.id['profile_number']))
    dc.add_link(ComponentLink([history.id['star_index']], profiles.id['star_index']))
    dc.add_link(ComponentLink([history.id['star_index']], desc.id['star_index']))
    dc.add_link(ComponentLink([history.id['mass']], profiles.id['mass']))
    dc.add_link(ComponentLink([history.id['mass']], desc.id['mass']))
    dc.add_link(ComponentLink([history.id['cb']], profiles.id['cb']))
    dc.add_link(ComponentLink([history.id['cb']], desc.id['cboost']))
    dc.add_link(ComponentLink([history.id['other']], profiles.id['other']))
    dc.add_link(ComponentLink([history.id['other']], desc.id['other']))
gfncs['link_HPD']= {'name':'link_HPD', \
                    'Signature':inspect.signature(link_HPD), \
                    'Docstring':inspect.getdoc(link_HPD), \
                    'class':'data'}
