#!/usr/bin/env Rscript

require(rhdf5)

require(argparser)

psr <- arg_parser("plot coefficients")
psr <- add_argument(psr, "--up", help="up shooting vertex fits")
psr <- add_argument(psr, "--down", help="down shooting vertex fits")
psr <- add_argument(psr, "--transverse", help="y-direction shooting vertex fits")
psr <- add_argument(psr, "-o", help="output file")
argv <- parse_args(psr)

vup <- h5read(argv$up, "vertex")

vdown <- h5read(argv$down, "vertex")

vtransverse <- h5read(argv$transverse, "vertex")
o <- mean(c(subset(vup, z0 >= -5000 & z0 <= 5000)$zm0, -subset(vdown, z0 >= -5000 & z0 <= 5000)$zm0, subset(vtransverse, z0 >= -10000 & z0 <= 10000)$ym))
write.table(o, argv$o, col.names=FALSE, row.names=FALSE)

