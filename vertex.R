#!/usr/bin/env Rscript
# plot vertex distributions

require(plyr)
require(rhdf5)
require(argparser)

psr <- arg_parser("plot coefficients")
psr <- add_argument(psr, "--input", nargs=Inf, help="input coefficients files")
psr <- add_argument(psr, "--offset", short="-r", nargs=Inf, help="vertex offset")
psr <- add_argument(psr, "-o", help="output file")
argv <- parse_args(psr)

if (is.na(argv$offset)) {
    offset <- c(0,0,0)
} else {
    offset <- as.numeric(read.table(argv$offset))
}

loadf <- function(fn) {
    fid <- H5Fopen(fn)
    z0 <- as.numeric(gsub("z(.*)\\.h5", "\\1", basename(fn)))
    r0 <- sqrt(sum((c(0,0,z0) + offset)^2))
    rst <- cbind(h5read(fid, "ol"), r0, z0)
    H5Fclose(fid)
    rst
}

d <- ldply(argv$input, loadf)

print(subset(d, abs(x)>1000))
d <- subset(d, abs(x)<1000)

d$r <- sqrt(d$x^2 + d$y^2 + d$z^2)

require(dplyr)
ds <- d %>% group_by(z0) %>% summarise(xerr=sd(x), xm=mean(x), yerr=sd(y), ym=mean(y), zerr=sd(z), zm=mean(z), rerr=sd(r), rm=mean(r))

ds$zm0 = ds$zm - (ds$z0 + offset[3])

require(ggplot2)
pdf(sub(".h5", ".pdf", argv$o), 9, 6)
p <- ggplot(ds, aes(x=z0, y=xm, ymin=xm-xerr, ymax=xm+xerr)) + geom_errorbar() + geom_point() + ylab("x/mm")
print(p)
p <- p + aes(y=ym, ymin=ym-yerr, ymax=ym+yerr) + ylab("y/mm")
print(p)
p <- p + aes(y=zm, ymin=zm-zerr, ymax=zm+zerr) + ylab("z/mm")
print(p)
p <- p + aes(y=zm0, ymin=zm0-zerr, ymax=zm0+zerr) + ylab("(z-z0)/mm")
print(p)
p <- p + aes(y=rm, ymin=rm-rerr, ymax=rm+rerr) + ylab("r/mm")
dev.off()
fid <- H5Fcreate(argv$o)
h5save(ds, name="vertex", file=fid, native=TRUE)
H5Fclose(fid)
