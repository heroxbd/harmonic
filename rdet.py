#!/usr/bin/env python3
'''
Read JUNO detector simulation and convert it into PE .h5
'''

import argparse, uproot, h5py, numpy as np

psr = argparse.ArgumentParser()
psr.add_argument("-o", dest='opt', help='output')
psr.add_argument('ipt', help='JUNO detector simulation input')
psr.add_argument('-z', help='Position z')
args = psr.parse_args()

f = uproot.open(args.ipt)
e = f['evt']
pmtID = e.array('pmtID')
evtID = np.concatenate([np.repeat(e, len(p)) for e, p in zip(e.array('evtID'), pmtID)])

with h5py.File(args.opt,'w') as opt:
    opt.attrs['z'] = int(args.z)

    gt = opt.create_dataset('PETruth', (len(evtID) ,), [('EventID', 'u4'), ('ChannelID', 'u2'), ('PETime', 'f4')], compression="gzip", shuffle=True)
    gt['EventID'] = evtID
    gt['ChannelID'] = np.concatenate(pmtID)
    gt['PETime'] = np.concatenate(e.array('hitTime'))
