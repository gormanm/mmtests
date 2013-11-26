
plottitle <- ""
xlabel <- ""
ylabel <- ""
smooth <- FALSE
format <- "png"
outfile <- ""
subtitle <- ""

plottypeToPlotFunction <- list(
  boxplot = "mm.boxplot",
  candlestick = "mm.boxplot",
  candlesticks = "mm.boxplot",
  "run-sequence" = "mm.runsequence"
);

init.output <- function (format, file) {
	if (format == "png") {
		png(file, width=640, height=480)
	} else {
		postscript(file)
	}
}

mm.runsequence <- function(values, main=plottitle, xlab=xlabel, ylab=ylabel, sub=subtitle) {
	if (smooth) {
		pch <- "."
	} else {
		pch <- 1
	}
	plot (values, main=main, xlab=xlab, ylab=ylab, sub=sub, pch=pch)
}

mm.boxplot <- function(values, main=plottitle, xlab=xlabel, ylab=ylabel, sub=subtitle) {
	boxplot (values, main=main, xlab=xlab, ylab=ylab, sub=sub, outline=!smooth)
}

mm.plot <- function(results, plottype) {
	init.output (format, outfile)

	fun <- plottypeToPlotFunction[[plottype]]
	values <- lapply(results, FUN=function(x) { return (x[[2]]);} )
	do.call (fun, list(values));

	dev.off();
}

mm.multiplot <- function(results, plottype) {
	# this function expects that outfile doesn't contain extension, for simplicity
	if (format == "png") {
		ext <- "png"
	} else {
		ext <- "ps"
	}

	values <- lapply(results, FUN=function(x) { return (x[[2]]);} )
	fun <- plottypeToPlotFunction[[plottype]]

	for (i in seq (length(results))) {
		subfile <- paste (outfile, i, sep="-")
		if (smooth) {
			subfile <- paste (subfile, "smooth", sep="-")
		}
		subfile <- paste (subfile, ext, sep=".")
		init.output (format, subfile)

		do.call (fun, list(values[[i]], xlab="Sample", sub=names(values)[[i]]));

		dev.off()
	}
}