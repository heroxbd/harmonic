#!/usr/bin/env python3
import h5py, argparse, os
psr = argparse.ArgumentParser()
psr.add_argument("-f", nargs='+', dest='fields', default=[], help="link fields")
psr.add_argument("ipt", help="file to be manipulated")
psr.add_argument("-t", dest='target', help="target file")
psr.add_argument("-n", dest='noattr', action="store_true", help="do not copy attributes")
args = psr.parse_args()

with h5py.File(args.ipt, 'a') as ipt, h5py.File(args.target, 'r') as target:
    for f in args.fields:
        s = '' if f[0]=='/' else '/'
        if f in ipt.keys():
            del ipt[f]
        ipt[f]=h5py.ExternalLink(os.path.relpath(args.target, 
                                                 os.path.dirname(args.ipt)),
                                 s+f)
    if not args.noattr:
        for k, v in target.attrs.items():
            ipt.attrs[k] = v
