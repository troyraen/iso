# To copy history.data files stripped of all non-essential columns:
Check file paths in hdat_clean.sh.
Then run that file. It takes a cboost value as input,
finds history.data files in specified directory,
then calls hdat_clean.py which generates a new history.data file in new location

# To generate isochrone input file:
Check that the cleaned history.data files are in dir iso/data/tracks/cb.
Then run genisoinput.sh to generate input file for make_eep and make_iso
(and optionally run make_eep and make_iso).
Make sure correct history_columns.list file is in main iso dir before
running make_eep or make_iso.

# My Plotting:
Use glue/convert_iso_file.py to convert isochrone data output to a csv file
and then run glue.

The plotting info below is old and never worked...

Plotting:
mesa_plot_grid.py and read_mist_models.py can be used for plotting.
Use mesa_plot_grid.plot_iso('MIST_vXX/feh_XXX_afe_XXX')
mv data dir to MIST_vXX/feh_XXX_afe_XXX/ first


import pandas as pd
isofile = '/Users/troyraen/Google_Drive/MESA/code/iso/data/isochrones/isochrone_c0.dat'
names = [ 'EEP','log10_isochrone_age_yr','initial_mass','star_mass',\
    'log_LH','log_LHe','log_Teff','log_L','log_g','log_center_T',\
    'log_center_Rho','center_h1','center_he4','center_c12','center_gamma',\
    'surface_h1','he_core_mass','c_core_mass','phase']
df = pd.read_csv(isofile, sep='\s+', names=names, comment='#', skip_blank_lines=True)



# may need:
import importlib as imp # imp.reload(mod) to reload module
export ISO_DIR=$(pwd)
export MIST_GRID_DIR=$(pwd)
