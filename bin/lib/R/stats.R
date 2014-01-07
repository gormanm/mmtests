
datatypeToStatsFunction <- list(
  WalltimeOutliers = "calc.quartiles"
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

calc.stats <- function (results, datatype) {
	fun <- datatypeToStatsFunction[[datatype]]
	do.call (fun, list(results));
}
