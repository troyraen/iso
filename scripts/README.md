# To strip history.data files of all non-essential columns:
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
