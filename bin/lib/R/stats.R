
datatypeToStatsFunction <- list(
	WalltimeOutliers = "calc.quartiles",
	PercentageAllocated = "calc.percentageAllocated"
);

meanhighestX <- function(data, X) {
	return (mean(data[data > quantile(data, X)]))
}

calc.quartiles <- function(results) {
	values <- lapply(results, FUN=function(x) { return (x[[2]]);} )

	output <- sapply(values, quantile, c(0,0.25,0.50,0.75,0.90,0.95,0.99,1))

	output <- rbind (output, sapply (values, FUN=meanhighestX, 0.90))
	output <- rbind (output, sapply (values, FUN=meanhighestX, 0.95))
	output <- rbind (output, sapply (values, FUN=meanhighestX, 0.99))

	rownames(output) <- c("Min", "1st Q", "Median", "3rd Q", "90%", "95%", "99%", "Max", "Worst10%Mean", "Worst5%Mean", "Worst1%Mean")

	return (output)
}

calc.percentageAllocated <- function(results) {
	if ("Iteration" %in% names (results[[1]])) {
		# aggregate over kernels as columns
		values <- sapply(results, FUN=function(x) {
			# min, mean, max per benchmark phase
			unlist(tapply (x$Success, x$Pass, function (y) {
				return (c(min(y), mean(y), max(y)));
			}))
		})
		stats <- c("Min", "Mean", "Max")
		rownames (values) <- c(paste("Success 1", stats), paste("Success 2", stats), paste("Success 3", stats))
		return (values)
	} else {
		values <- sapply(results, FUN=function(x) { return (x[[2]]);} )
		rownames(values) <- c("Success 1", "Success 2", "Success 3")
		return (values)
	}
}


calc.stats <- function (results, datatype) {
	fun <- datatypeToStatsFunction[[datatype]]
	do.call (fun, list(results));
}
