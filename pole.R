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
    v0 <- h5read(fid, "v0")
    r <- sqrt(sum(v0^2))
    rst <- cbind(h5read(fid, "coef"), r, zs=sign(v0[3]))
    H5Fclose(fid)
    rst
}

d <- ldply(argv$input, loadf)
d$zs <- as.factor(d$zs)

pdf(sub(".h5", ".pdf", argv$o), 13, 7)
require(ggforce)
p <- ggplot(d, aes(x=r, y=Value, ymin=Value-stderr, ymax=Value+stderr, color=zs)) + geom_point() + xlab("r/mm") + ylab("t/ns")
p <- p + geom_errorbar()
p <- p + facet_wrap(~order, scales="free")
print(p)
dev.off()

fid <- H5Fcreate(argv$o)
h5save(d, name="coef", file=fid, native=TRUE)
H5Fclose(fid)
