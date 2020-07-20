#!/usr/bin/env Rscript
# plot vertex distributions

require(plyr)
require(rhdf5)
require(argparser)

psr <- arg_parser("plot coefficients")
psr <- add_argument(psr, "--input", nargs=Inf, help="input coefficients files")
psr <- add_argument(psr, "-o", help="output file")
argv <- parse_args(psr)

loadf <- function(fn) {
    fid <- H5Fopen(fn)
    rst <- cbind(h5read(fid, "ol"), z0=as.numeric(gsub("z(.*)\\.h5", "\\1", basename(fn))))
    H5Fclose(fid)
    rst
}

d <- ldply(argv$input, loadf)

print(subset(d, abs(x)>1000))
d <- subset(d, abs(x)<1000)

require(dplyr)
ds <- d %>% group_by(z0) %>% summarise(xerr=sd(x), xm=mean(x), yerr=sd(y), ym=mean(y), zerr=sd(z), zm=mean(z))

ds$zm0 = ds$zm - ds$z0

require(ggplot2)
pdf(argv$o, 9, 6)
p <- ggplot(ds, aes(x=z0, y=xm, ymin=xm-xerr, ymax=xm+xerr)) + geom_errorbar() + geom_point() + ylab("x/mm")
print(p)
p <- p + aes(y=ym, ymin=ym-yerr, ymax=ym+yerr) + ylab("y/mm")
print(p)
p <- p + aes(y=zm, ymin=zm-zerr, ymax=zm+zerr) + ylab("z/mm")
print(p)
p <- p + aes(y=zm0, ymin=zm0-zerr, ymax=zm0+zerr) + ylab("(z-z0)/mm")
print(p)
dev.off()
