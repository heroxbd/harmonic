#!/usr/bin/env Rscript

require(plyr)
require(rhdf5)
require(argparser)

psr <- arg_parser("plot coefficients")
psr <- add_argument(psr, "--input", nargs=Inf, help="input coefficients files")
psr <- add_argument(psr, "-o", help="output file")
argv <- parse_args(psr)

loadf <- function(fn) {
    fid <- H5Fopen(fn)
    rst <- cbind(h5read(fid, "coef"), z=h5readAttributes(fid, "/")$z)
    H5Fclose(fid)
    rst
}

d <- ldply(argv$input, loadf)

pdf(argv$o, 13, 7)
require(ggforce)
p <- ggplot(d, aes(x=z, y=Value, ymin=Value-stderr, ymax=Value+stderr)) + geom_point() + xlab("z/mm") + ylab("t/ns")
p <- p + geom_errorbar()
p <- p + facet_wrap(~order, scales="free")
print(p)
dev.off()
