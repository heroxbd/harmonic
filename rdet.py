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
pID = np.concatenate(pmtID)
ht = np.concatenate(e.array('hitTime'))
primary = ht < 4096
secondary = np.logical_not(primary)

with h5py.File(args.opt,'w') as opt:
    opt.attrs['z'] = int(args.z)

    gt = opt.create_dataset('PETruth', (np.sum(primary) ,), [('EventID', 'u4'), ('ChannelID', 'u4'), ('PETime', 'f8')], compression="gzip", shuffle=True)
    gt['EventID'] = evtID[primary]
    gt['ChannelID'] = pID[primary]
    gt['PETime'] = ht[primary]

    gt2 = opt.create_dataset('secondary/PETruth', (np.sum(secondary) ,), [('EventID', 'u4'), ('ChannelID', 'u4'), ('PETime', 'f8')], compression="gzip", shuffle=True)
    gt2['EventID'] = evtID[secondary]
    gt2['ChannelID'] = pID[secondary]
    gt2['PETime'] = ht[secondary]
