import numpy as np


# converts isochrone output files (isochrone_cb.dat) to isochrones.csv for Glue
# can combine files from multple cboosts
def iso_to_csv(cboost=[0], append_cb=True):
    isodir = '/Users/troyraen/Google_Drive/MESA/code/iso'
    fout = isodir+'/glue/isochrones.csv'

    for i, cb in enumerate(cboost):
        print(i)
        fin = isodir+'/data/isochrones/isochrone_c'+str(cb)+'.dat'
        # get column names and make sure they're the same across files
        if i == 0:
            isoheader, cnt = get_columns(fin, cboost=append_cb)
            alldata = np.empty((1,cnt))
        else:
            hdr, __ = get_columns(fin, cboost=append_cb)
            if hdr != isoheader:
                print()
                print(fin, 'COLUMNS DO NOT MATCH isochrone_c0.dat')
                print()

        # get data
        newdata = np.genfromtxt(fin, comments='#')
        if append_cb:
            cbarr = cb*np.ones((newdata.shape[0],1))
            newdata = np.append(newdata, cbarr, axis=1)
        alldata = np.concatenate((alldata, newdata), axis=0)

    # write new file
    np.savetxt(fout, alldata, delimiter=',', header=isoheader, comments='')


# returns column names as a list
# optionally adds cboost to the end
def get_columns(isofile, cboost=False):
    # get column names, ignore leading '#'
    isoheader = np.genfromtxt(isofile, dtype='str', \
            skip_header=10, comments=None, max_rows=1)[1:].tolist()
    if cboost:
        isoheader.append('cboost')
    cnt = len(isoheader)
    isoheader = ','.join(isoheader[i] for i in range(len(isoheader)))
    return [isoheader, cnt]
