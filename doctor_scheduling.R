# TODO: Description
# TODO: also write doctors template
# TODO: issue: a request for N2 will always be ignored if there is a request for N, use a binary mask for soft requests
# TODO: make shifts a factor, then use it for input validation
require(Hmisc)
require(xlsx)




### static variables
# TODO: once this is a package, see to it that these can not be overwritten

day_shifts <- c("5", "6", "7", "8", "8.5", "9", "10")
day_shifts_absent <- c("FB5", "FB6", "FB7", "FB8")
day_requests <- c(day_shifts, day_shifts_absent, "<5", "<6", "<7", "<8", "<9", "<10")
N_shifts <- c("N", "N1", "N2")
holiday_shifts <- c("U", "SU", "ZA", "NG")

if(file.exists("holidays.list"))
{
	holidays <- as.Date(as.character(read.csv("holidays.list", header = FALSE)$V1))
} else
{
	warning("No 'holidays.list' file found. This file should contain dates of holiday in the format YYYY-MM-DD, separated by newlines, specifying holidays (Gesetzliche Feiertage). Proceeding without any holidays")
}




# TODO: input validation
read.doctors <- function(file = "doctors.csv")
{
	doctors <- read.csv(file, row.names = 1)
	
	doctors$split_shifts  <- doctors$split_shifts == "yes"
	doctors$friday_sunday <- doctors$friday_sunday == "yes"
	
# 	doctors$number_of_shifts_factor <- rep(1)
# 	if(all(c("less", "more") %in% doctors$number_of_shifts))
# 	{
# 		n.less <- sum(doctors$number_of_shifts == "less")
# 		n.more <- sum(doctors$number_of_shifts == "more")
# 		deviation <- 0.25
# 		if(n.less < n.more)
# 		{
# 			doctors$number_of_shifts_factor[doctors$number_of_shifts == "less"] <- 1 - deviation
# 			doctors$number_of_shifts_factor[doctors$number_of_shifts == "more"] <- 1 + deviation * n.less / n.more
# 		} else
# 		{
# 			doctors$number_of_shifts_factor[doctors$number_of_shifts == "more"] <- 1 + deviation
# 			doctors$number_of_shifts_factor[doctors$number_of_shifts == "less"] <- 1 - deviation * n.more / n.less
# 		}
# 	}
	
	doctors$hours_min      <- rep(NA)
	doctors$hours_min_work <- rep(NA)
	doctors$hours_max_work <- rep(NA)
# 	doctors$hours_max_AZG  <- rep(NA)
	doctors$hours  <- rep(0)
	doctors$weekhours_work <- rep(NA)
	
	doctors$shifts_target  <- rep(NA)
	doctors$weekends_target  <- rep(NA)
	doctors$shifts <- rep(0)
	doctors$days   <- rep(0)
	doctors$nights <- rep(0)
	doctors$weekends <- rep(0)
	
# 	doctors$conflicts_won  <- rep(0)
# 	doctors$conflicts_lost <- rep(0)
	doctors$requests_granted <- rep(0)
	doctors$requests_denied  <- rep(0)
	doctors$soft_requests_granted <- rep(0)
	doctors$soft_requests_denied  <- rep(0)
	
# 	doctors$fridays   <- rep(0)
# 	doctors$saturdays <- rep(0)
# 	doctors$sundays   <- rep(0)
# 	doctors$fridays_relative   <- rep(0)
# 	doctors$saturdays_relative <- rep(0)
# 	doctors$sundays_relative   <- rep(0)
	
	doctors$shifts_carryover <- doctors$shifts_carryover - sum(doctors$shifts_carryover) / length(doctors$shifts_carryover)
	doctors$weekends_carryover <- doctors$weekends_carryover - sum(doctors$weekends_carryover) / length(doctors$weekends_carryover)
	
	return(doctors)
}




# write.template.csv <- function(file = "template.csv", start_date, end_date, doctors = read.doctors(), date_format = NA)
# {
# 	dates <- as.character(seq(from=start_date, to=end_date, by=1))
# 	
# 	template <- matrix(rep(""), length(rownames(doctors)), length(dates), dimnames = list(rownames(doctors), as.character(dates)))
# 	
# 	if(!is.na(date_format))
# 		colnames(template) <- format(as.Date(colnames(template)), date_format)
# 	write.csv(template, file = file, quote = FALSE)
# }




# XLSX version
# this is a bit tedious, but we can have formatted spreadsheets
write.templates <- function(start_date, end_date, doctors = read.doctors("doctors.csv"))
{
	dates <- seq(from=start_date, to=end_date, by=1)
	
	template <- matrix(rep(""), length(rownames(doctors)), length(dates), dimnames = list(rownames(doctors), format(dates, format="%d")))
	
	# here begins the xlsx stuff
	wb <- createWorkbook()
	sheet <- createSheet(wb, sheetName=format(start_date, format="%Y-%m"))
	addDataFrame(as.data.frame(template), sheet)
	rows  <- getRows(sheet)
	cells <- getCells(rows)
	
	# YYYY-MM in topleft cell
	setCellValue(cells[["1.1"]], format(start_date, format="%Y-%m"))
	
	cellstyle.table <- CellStyle(wb) + Border(color="black", position = c("TOP", "LEFT", "BOTTOM", "RIGHT"))
	for(day in seq_along(dates))
	{
		for(row in seq_along(rownames(doctors)))
		{
			setCellStyle(cells[[paste(row + 1, day + 1, sep = ".")]], cellstyle.table)
		}
	}
	
	# Colored background for weekends
	cellstyle.holiday <- cellstyle.table + Fill(foregroundColor="#add8e6")
	for(day in seq_along(dates))
	{
		if(!is.workday(dates[day]))
		{
			for(row in seq_along(rownames(doctors)))
			{
				setCellStyle(cells[[paste(row + 1, day + 1, sep = ".")]], cellstyle.holiday)
			}
		}
	}
	
	# Resize Columns
	autoSizeColumn(sheet, 1)
	for(column in 2:(length(dates)+1))
	{
		setColumnWidth(sheet, column, 5)
	}
	
	if(file.exists("requests.xlsx"))
	{
		message("WARNING: File 'requests.xlsx' already exists, cowardly refusing to overwrite")
	} else
	{
		saveWorkbook(wb, "requests.xlsx")
	}
	
	
	
	
	# ward min presence table
	template <- matrix(rep(""), length(unique(doctors$ward)), length(dates), dimnames = list(unique(doctors$ward), format(dates, format="%d")))
	
	# here begins the xlsx stuff
	wb <- createWorkbook()
	sheet <- createSheet(wb, sheetName=format(start_date, format="%Y-%m"))
	addDataFrame(as.data.frame(template), sheet)
	rows  <- getRows(sheet)
	cells <- getCells(rows)
	
	# YYYY-MM in topleft cell
	setCellValue(cells[["1.1"]], format(start_date, format="%Y-%m"))
	
	cellstyle.table <- CellStyle(wb) + Border(color="black", position = c("TOP", "LEFT", "BOTTOM", "RIGHT"))
	for(day in seq_along(dates))
	{
		for(row in seq_along(unique(doctors$ward)))
		{
			setCellStyle(cells[[paste(row + 1, day + 1, sep = ".")]], cellstyle.table)
		}
	}
	
	# Colored background for weekends
	cellstyle.holiday <- cellstyle.table + Fill(foregroundColor="#add8e6")
	for(day in seq_along(dates))
	{
		if(!is.workday(dates[day]))
		{
			for(row in seq_along(unique(doctors$ward)))
			{
				setCellStyle(cells[[paste(row + 1, day + 1, sep = ".")]], cellstyle.holiday)
			}
		}
	}
	
	# Resize Columns
	autoSizeColumn(sheet, 1)
	for(column in 2:(length(dates)+1))
	{
		setColumnWidth(sheet, column, 5)
	}
	
	if(file.exists("wards.xlsx"))
	{
		message("WARNING: File 'wards.xlsx' already exists, cowardly refusing to overwrite")
	} else
	{
		saveWorkbook(wb, "wards.xlsx")
	}
}




# XLSX version
# this is a bit tedious, but we can have formatted spreadsheets
write.schedule <- function(schedule = NA, wards = NA, doctors = NA, opt_parms = NA)
{
	dates <- as.Date(colnames(schedule))
	colnames(schedule) <- format(dates, format="%d")
	
	# here begins the xlsx stuff
	wb <- createWorkbook()
	sheet <- createSheet(wb, sheetName=format(start_date, format="%Y-%m"))
	addDataFrame(as.data.frame(schedule), sheet)
	addDataFrame(as.data.frame(wards$presence - wards$min_presence), sheet, col.names = FALSE, startRow = length(rownames(doctors)) + 3)
	rows  <- getRows(sheet)
	cells <- getCells(rows)
	
	# YYYY-MM in topleft cell
	setCellValue(cells[["1.1"]], format(start_date, format="%Y-%m"))
	
	cellstyle.table <- CellStyle(wb) + Border(color="black", position = c("TOP", "LEFT", "BOTTOM", "RIGHT"))
	for(day in seq_along(dates))
	{
		for(row in seq_along(rownames(doctors)))
		{
			setCellStyle(cells[[paste(row + 1, day + 1, sep = ".")]], cellstyle.table)
		}
	}
	
	# Colored background for weekends
	cellstyle.holiday <- cellstyle.table + Fill(foregroundColor="#add8e6")
	for(day in seq_along(dates))
	{
		if(!is.workday(dates[day]))
		{
			for(row in seq_along(rownames(doctors)))
			{
				setCellStyle(cells[[paste(row + 1, day + 1, sep = ".")]], cellstyle.holiday)
			}
		}
	}
	
	# Colored background for specific shifts
	cellstyle.holiday <- cellstyle.table + Fill(foregroundColor="#add8e6")
	cellstyle.N <- cellstyle.table + Fill(foregroundColor="#00cc00")
	cellstyle.N1 <- cellstyle.table + Fill(foregroundColor="#cccc00")
	cellstyle.N2 <- cellstyle.table + Fill(foregroundColor="#00cccc")
	for(day in seq_along(dates))
	{
		for(row in seq_along(rownames(doctors)))
		{
			value <- getCellValue(cells[[paste(row + 1, day + 1, sep = ".")]])
			if(value %in% c("X", "FT", "-", holiday_shifts))
			{
				setCellStyle(cells[[paste(row + 1, day + 1, sep = ".")]], cellstyle.holiday)
			} else if(value == "N")
			{
				setCellStyle(cells[[paste(row + 1, day + 1, sep = ".")]], cellstyle.N)
			} else if(value == "N1")
			{
				setCellStyle(cells[[paste(row + 1, day + 1, sep = ".")]], cellstyle.N1)
			} else if(value == "N2")
			{
				setCellStyle(cells[[paste(row + 1, day + 1, sep = ".")]], cellstyle.N2)
			}
		}
	}
	
	# Colored background for day presence
	cellstyle.red3 <- CellStyle(wb) + Fill(foregroundColor="#ff0000")
	cellstyle.red2 <- CellStyle(wb) + Fill(foregroundColor="#ff5555")
	cellstyle.red1 <- CellStyle(wb) + Fill(foregroundColor="#ffaaaa")
	cellstyle.green1 <- CellStyle(wb) + Fill(foregroundColor="#aaffaa")
	cellstyle.green2 <- CellStyle(wb) + Fill(foregroundColor="#55ff55")
	cellstyle.green3 <- CellStyle(wb) + Fill(foregroundColor="#00ff00")
	for(day in seq_along(dates))
	{
		if(is.workday(dates[day]))
		{
			for(row in seq_along(rownames(wards$presence_missing)))
			{
				value <- getCellValue(cells[[paste(row + length(rownames(doctors)) + 2, day + 1, sep = ".")]])
				if(value < 0)
					setCellStyle(cells[[paste(row + length(rownames(doctors)) + 2, day + 1, sep = ".")]], cellstyle.red1)
				if(value < -1)
					setCellStyle(cells[[paste(row + length(rownames(doctors)) + 2, day + 1, sep = ".")]], cellstyle.red2)
				if(value < -2)
					setCellStyle(cells[[paste(row + length(rownames(doctors)) + 2, day + 1, sep = ".")]], cellstyle.red3)
				if(value > 0)
					setCellStyle(cells[[paste(row + length(rownames(doctors)) + 2, day + 1, sep = ".")]], cellstyle.green1)
				if(value > 1)
					setCellStyle(cells[[paste(row + length(rownames(doctors)) + 2, day + 1, sep = ".")]], cellstyle.green2)
				if(value > 2)
					setCellStyle(cells[[paste(row + length(rownames(doctors)) + 2, day + 1, sep = ".")]], cellstyle.green3)
			}
		}
	}
	
	# Resize Columns
	autoSizeColumn(sheet, 1)
	for(column in 2:(length(dates)+1))
	{
		setColumnWidth(sheet, column, 5)
	}
	
	
	sheet2 <- createSheet(wb, sheetName="doctors.stats")
	addDataFrame(as.data.frame(doctors), sheet2)
# 	for(column in 1:(length(dates)+1))
# 	{
# 		autoSizeColumn(sheet2, column)
# 	}
	
	
	saveWorkbook(wb, "schedule.xlsx")
}




# TODO: input validation
# TODO: not very elegant, but this requires doctors as input to select relevant part of the xlsx file (and not comments etc)
read.requests <- function(file = "requests.xlsx", doctors = read.doctors("doctors.csv"))
{
	#colClasses="character" doesn't seem to work, it is coerced to factor
	raw <- read.xlsx(file, sheetIndex=1, rowIndex=0:length(rownames(doctors)) + 1, colClasses="character")
	raw <- as.matrix(raw)
	raw[is.na(raw)] <- ""
	# i have no idea why colnames are prefixed with "X" when reading xlsx
	colnames(raw) <- sub("^X", "", colnames(raw))
	# i also don't know why "-" is converted to "." when reading xlsx
	date.ym <- sub("\\.", "-", colnames(raw)[1])
	
	requests <- raw[,-1]
	dimnames(requests) <- list(raw[,1], paste(date.ym, colnames(raw)[-1], sep = "-"))
	
	# change U or ZA on holidays to !N
	requests[,!is.workday(colnames(requests))][requests[,!is.workday(colnames(requests))] %in% c("U", "ZA")] <- "!N"
	return(requests)
}




# TODO: input validation
# TODO: not very elegant, but this requires doctors as input to select relevant part of the xlsx file (and not comments etc)
read.wards <- function(file = "wards.xlsx", doctors = read.doctors("doctors.csv"))
{
	#colClasses="character" doesn't seem to work, it is coerced to factor
	raw <- read.xlsx(file, sheetIndex=1, rowIndex=0:length(unique(doctors$ward)) + 1, colClasses="character")
	raw <- as.matrix(raw)
	raw[is.na(raw)] <- ""
	# i have no idea why colnames are prefixed with "X" when reading xlsx
	colnames(raw) <- sub("^X", "", colnames(raw))
	# i also don't know why "-" is converted to "." when reading xlsx
	date.ym <- sub("\\.", "-", colnames(raw)[1])
	
	wards.min_presence <- raw[,-1]
	dimnames(wards.min_presence) <- list(raw[,1], paste(date.ym, colnames(raw)[-1], sep = "-"))
	
	mode(wards.min_presence) <- "numeric"
	wards.min_presence[is.na(wards.min_presence)] <- 0
	
	names <- rownames(wards.min_presence)
	dates <- colnames(wards.min_presence)
	empty_matrix <- matrix(rep(0), length(names), length(dates), dimnames = list(names, as.character(dates)))
	
	wards <- list(min_presence    = wards.min_presence, 
	              presence    = empty_matrix, 
	              hours    = empty_matrix)
	
	return(wards)
}




# # TODO: input validation
# read.requests.csv <- function(file = "requests.csv")
# {
# 	requests <- as.matrix(read.csv(file, row.names = 1, colClasses = "character", check.names = FALSE))
# 	
# 	# change U or ZA on holidays to !N
# 	requests[,!is.workday(colnames(requests))][requests[,!is.workday(colnames(requests))] %in% c("U", "ZA")] <- "!N"
# 	return(requests)
# }




# read.wards.csv <- function(file = "wards.min_presence.csv")
# {
# 	wards.min_presence <- as.matrix(read.csv(file, row.names = 1, check.names = FALSE))
# 	wards.min_presence[is.na(wards.min_presence)] <- 0
# 	
# 	names <- rownames(wards.min_presence)
# 	dates <- colnames(wards.min_presence)
# 	empty_matrix <- matrix(rep(0), length(names), length(dates), dimnames = list(names, as.character(dates)))
# 	
# 	wards <- list(min_presence    = wards.min_presence, 
# 	              presence    = empty_matrix, 
# 	              hours    = empty_matrix)
# 	
# 	return(wards)
# }




# Strip "soft" requests (matching the pattern "?.*")
# hardmode: TRUE, FALSE, or numeric in between 0 and 1:
# if FALSE, grant all soft requests, if TRUE, deny all soft requests, if in between, randomly grant proportion of soft requests
strip.requests <- function(requests, hardmode = FALSE)
{
	if(hardmode == FALSE)
	{
		requests <- sub("\\?", "", requests)
	} else if (hardmode == TRUE)
	{
		requests <- sub(".*\\?.*", "", requests)
	} else
	{
		prob <- 1 - hardmode
		requests.soft <- grep("\\?", requests)
		requests.grant <- as.logical(rbinom(length(requests.soft), size = 1, prob = prob))
		requests[requests.soft][requests.grant]  <- sub("\\?", "", requests[requests.soft][requests.grant])
		requests[requests.soft][!requests.grant] <- sub(".*\\?.*", "", requests[requests.soft][!requests.grant])
	}
	return(requests)
}




# strip.wards <- function(wards = read.wards(), subset = NULL)
# {
# 	if(!subset %in% c("FA", "AA"))
# 		return(NULL)
# 	
# 	out <- wards[grep(paste0("\\.", subset), names(wards))]
# 	names(out) <- sub(paste0("\\.", subset), "", names(out))
# 	
# 	return(out)
# }




is.holiday <- function(dates)
{
	x <- as.Date(dates) %in% holidays
	return(x)
}




is.sunday <- function(dates)
{
	x <- weekdays(as.Date(dates)) == "Sunday"
	return(x)
}




is.saturday <- function(dates)
{
	x <- weekdays(as.Date(dates)) == "Saturday"
	return(x)
}




is.friday <- function(dates)
{
	x <- weekdays(as.Date(dates)) == "Friday"
	return(x)
}




is.workday <- function(dates)
{
	x <- !is.holiday(dates) & !is.sunday(dates) & !is.saturday(dates)
	return(x)
}




is.fridaylike <- function(dates)
{
	next_days <- as.Date(dates) + 1
	x <- is.workday(dates) & !is.workday(next_days)
	return(x)
}




is.saturdaylike <- function(dates)
{
	next_days <- as.Date(dates) + 1
	x <- !is.workday(dates) & !is.workday(next_days)
	return(x)
}




is.sundaylike <- function(dates)
{
	next_days <- as.Date(dates) + 1
	x <- !is.workday(dates) & is.workday(next_days)
	return(x)
}




# x: shift(s), also works for matrix of shifts
# Output: Work Hours
as.hours <- function(x, count_holidays = FALSE)
{
	if(length(x) > 1)
	{
		if(is.matrix(x))
		{
			hours <- matrix(rep(0), nrow = nrow(x), ncol = ncol(x), dimnames = dimnames(x))
		} else
		{
			hours <- numeric(length(x))
		}
		for(i in seq_along(x))
			hours[i] <- as.hours(x[i], count_holidays = count_holidays)
		return(hours)
	}
	
	if(length(x) == 0)
		return(0)
	
	if(x == "N")
		return(16)
	if(x == "N1")
		return(12.5)
	# TODO: the following two aren't entirely correct, fixing this will require differentiating X after N vs X after N2
	if(x == "N2")
		return(3.5)
	if(x == "X")
		return(9)
	if(x %in% day_shifts)
		return(as.numeric(x))
	if(x %in% day_shifts_absent)
		return(as.numeric(sub("FB", "", x)))
	if(x %in% day_requests)
		return(as.numeric(sub("<", "", x)))
	if(count_holidays && x %in% holiday_shifts)
		return(8)
	return(0)
}




# x: shift(s), also works for matrix of shifts
# Output: Work Hours
as.day_hours <- function(x)
{
	if(length(x) > 1)
	{
		if(is.matrix(x))
		{
			hours <- matrix(rep(0), nrow = nrow(x), ncol = ncol(x), dimnames = dimnames(x))
		} else
		{
			hours <- numeric(length(x))
		}
		for(i in seq_along(x))
			hours[i] <- as.day_hours(x[i])
		return(hours)
	}
	
	if(length(x) == 0)
		return(0)
	
	if(x %in% c("N", "N1"))
		return(5)
	if(x %in% day_shifts)
		return(as.numeric(x))
	if(x %in% day_shifts_absent)
		return(0)
	if(x %in% day_requests)
		return(as.numeric(sub("<", "", x)))
	return(0)
}




# TODO: this function should be overhauled together with shift variables at the top - it's easy to miss something
check.requests.granted <- function(requests, schedule)
{
	if(length(requests) > 1)
	{
		if(is.matrix(requests))
		{
			granted <- matrix(rep(NA), nrow = nrow(requests), ncol = ncol(requests), dimnames = dimnames(requests))
		} else
		{
			granted <- logical(length(requests))
		}
		for(i in seq_along(requests))
			granted[i] <- check.requests.granted(requests = requests[i], schedule = schedule[i])
		return(granted)
	}
		
	if(requests == "!N")
		return(!schedule %in% c("N", "N1", "N2"))
	if(requests == "!N1")
		return(!schedule %in% c("N", "N1"))
	if(requests == "!N2")
		return(!schedule %in% c("N", "N2"))
	# TODO: we need a variable for "<n" requests
	if(requests %in% day_requests && !requests %in% c(day_shifts, day_shifts_absent))
	{
		if(schedule %in% day_shifts)
			return(as.numeric(sub("<", "", requests)) >= as.numeric(schedule))
		if(schedule %in% c("X", "FT", "-"))
			return(TRUE)
		return(FALSE)
	}
	if(requests != "")
		return(requests == schedule)
	return(NA)
}




# TODO: this looks overly complicated for such an easy task
count.requests.granted <- function(requests, schedule)
{
	hard_requests <- strip.requests(requests, hardmode = TRUE)
	all_requests <- strip.requests(requests, hardmode = FALSE)
	soft_requests <- all_requests
	soft_requests[hard_requests != ""] <- ""
	hard_requests_granted <- check.requests.granted(requests = hard_requests, schedule = schedule)
	soft_requests_granted <- check.requests.granted(requests = soft_requests, schedule = schedule)
	n.hard_requests <- rowSums(!is.na(hard_requests_granted))
	n.soft_requests <- rowSums(!is.na(soft_requests_granted))
	hard_requests_granted[is.na(hard_requests_granted)] <- rep(FALSE)
	soft_requests_granted[is.na(soft_requests_granted)] <- rep(FALSE)
	n.hard_requests_granted <- rowSums(hard_requests_granted)
	n.soft_requests_granted <- rowSums(soft_requests_granted)
	n.hard_requests_denied <- n.hard_requests - n.hard_requests_granted
	n.soft_requests_denied <- n.soft_requests - n.soft_requests_granted
	return(list(requests_granted = n.hard_requests_granted,
	            requests_denied = n.hard_requests_denied,
	            soft_requests_granted = n.soft_requests_granted,
	            soft_requests_denied = n.soft_requests_denied))
}




# find doctor with the fewest hours or night shifts
pick.doctor <- function(doctors, sort_by, jitter = FALSE)
{
	# TODO: Description
	if(length(rownames(doctors)) == 1)
		return(rownames(doctors)[1])
	
	out <- matrix(numeric(), length(rownames(doctors)), 2, dimnames = list(rownames(doctors), c("sort_value", "enough")))
	if(sort_by == "hours")
	{
		out[,"sort_value"] <- doctors$hours / doctors$hours_min_work
		out[,"enough"] <- doctors$hours >= doctors$hours_min_work
	} else if(sort_by == "shifts")
	{
		out[,"sort_value"] <- doctors$shifts / doctors$shifts_target
		out[,"enough"] <- doctors$shifts >= doctors$shifts_target
	} else if(sort_by %in% c("days", "nights"))
	{
		out[,"sort_value"] <- doctors[,sort_by] / doctors$shifts_target
		out[,"enough"] <- doctors$shifts >= doctors$shifts_target
	} else if(sort_by == "weekends")
	{
		out[,"sort_value"] <- doctors$weekends / doctors$weekends_target
		out[,"enough"] <- doctors$weekends >= doctors$weekends_target
	}
	
	if(jitter && length(out[,"sort_value"]) > 1)
		out[,"sort_value"] <- out[,"sort_value"] * (1 - jitter) + runif(length(out[,"sort_value"]), min = min(out[,"sort_value"]), max = max(out[,"sort_value"])) * jitter
	
	# reshuffle
	out <- out[sample(rownames(out)),]
	# sort by sort_by
	out <- out[sort(out[,"sort_value"], index.return = TRUE)$ix,]
	# those with enough still come last
	out <- out[sort(out[,"enough"], index.return = TRUE)$ix,]
	# return first doctor
	return(rownames(out)[1])
}




# TODO: useful warnings
create.schedule <- function(doctors = read.doctors(), requests = read.requests(), wards = read.wards(), hardmode = FALSE, jitter = FALSE)
{
	warnings <- NULL
	opt_parms <- list(n.unresolved = 0, n.requests_denied = 0, n.soft_requests = 0, n.soft_requests_granted = 0, range.shifts = NA, range.weekends = NA, range.nights = NA, n.splittable = NA, n.split = NA, day_presence_missing = NA, day_presence_missing.squared = NA)
	days <- seq_along(colnames(requests))
	dates <- as.Date(colnames(requests))
	
	# Do all calendar lookups here for performance reasons
	is_holiday <- is.holiday(dates)
	is_sunday <- is.sunday(dates)
	is_saturday <- is.saturday(dates)
	is_friday <- is.friday(dates)
	is_workday <- !is_holiday & !is_sunday & !is_saturday
	is_sundaylike <- is.sundaylike(dates)
	is_saturdaylike <- is.saturdaylike(dates)
	is_fridaylike <- is.fridaylike(dates)
	is_splitday <- is_workday & !is_fridaylike
	
	schedule <- matrix(rep(""), length(rownames(doctors)), length(days), dimnames = list(rownames(doctors), as.character(dates)))
	requests.orig <- requests
	requests <- strip.requests(requests, hardmode = hardmode)
	
	# Calculate various hours
	hours_min <- sum(is_workday) * 8
	# TODO: take weekhours into account for non-40h-doctors
	doctors$hours_min <- hours_min
	doctors$hours_min_work <- doctors$hours_min - rowSums(requests == "U" | requests == "SU" | requests == "ZA" | requests == "NG") * 8 #TODO
	doctors$hours_max_work <- doctors$hours_min_work * (doctors$weekhours_max / 40)
	# TODO: this may not be entirely correct
# 	doctors$hours_max_AZG <- floor((doctors$hours_min - rowSums(requests == "U") * 8) * (48 / 40))
	
	doctors$shifts_target <- (doctors$hours_min_work - rowSums(requests == "FB8") * 8) * doctors$number_of_shifts_factor
	doctors$shifts_target <- doctors$shifts_target * length(days) / sum(doctors$shifts_target)
	doctors$shifts_target <- doctors$shifts_target - doctors$shifts_carryover
	doctors$shifts_carryover <- rep(0)
	
	doctors$weekends_target <- (doctors$hours_min_work - rowSums(requests == "FB8") * 8) * doctors$number_of_shifts_factor
	doctors$weekends_target <- doctors$weekends_target * (sum(is_fridaylike) * 0.4 + sum(is_saturdaylike) + sum(is_sundaylike) * 0.6) / sum(doctors$weekends_target)
	doctors$weekends_target <- doctors$weekends_target - doctors$weekends_carryover
	doctors$weekends_carryover <- rep(0)
	
	
	### preliminary - just enter days off ###########################################################
	for(day in days)
	{
		schedule[,day][requests[,day] %in% c(holiday_shifts, "FT")] <- requests[,day][requests[,day] %in% c(holiday_shifts, "FT")]
	}
	
	
	### preliminary - enter X on first day ##########################################################
	for(doctor in rownames(requests)[requests[,1] == "X"])
	{
		schedule[doctor,1] <- "X"
		if(requests[doctor,2] == "")
			requests[doctor,2] <- "!N1"
		doctors[doctor,"hours"] <- doctors[doctor,"hours"] + 9
		if(is_friday[7])
		{
			if((7) %in% days && requests[doctor, 7] == "")
				requests[doctor, 7] <- "!N"
			if((8) %in% days && requests[doctor, 8] == "")
				requests[doctor, 8] <- "!N"
	#		if((9) %in% days && requests[doctor, 9] == "")
	#			requests[doctor, 9] <- "!N"
		}
		if(is_saturday[7])
		{
			if((6) %in% days && requests[doctor, 6] == "")
				requests[doctor, 6] <- "!N"
			if((7) %in% days && requests[doctor, 7] == "")
				requests[doctor, 7] <- "!N"
			if((8) %in% days && requests[doctor, 8] == "")
				requests[doctor, 8] <- "!N"
		}
		if(is_sunday[7])
		{
			if((5) %in% days && requests[doctor, 5] == "")
				requests[doctor, 5] <- "!N"
			if((6) %in% days && requests[doctor, 6] == "")
				requests[doctor, 6] <- "!N"
			if((7) %in% days && requests[doctor, 7] == "")
				requests[doctor, 7] <- "!N"
		}
	}
	
	### preliminary - no night shifts before these requests
	for (day in days)
	{
		prev_day   <- day - 1
		
		if (prev_day %in% days)
			requests[,prev_day][requests[,prev_day] == "" & requests[,day] %in% c(day_shifts, day_shifts_absent, holiday_shifts, "FT", "-")] <- "!N2"
	}
	
	
	### iteration 1 - night shifts ##################################################################
	days.shuffled <- sample(days)
	
	n.available <- rep(0, length(days))
	for (day in days)
	{
		n.available[day] <- sum(schedule[,day] != "X" & requests[,day] %in% c("", "N"))
	}
	days.sorted <- days.shuffled[sort(n.available[days.shuffled], index.return = TRUE)$ix]
	
	dofirst <- colSums(requests == "N" | requests == "N1" | requests == "N2")[days.sorted] > 0
	
	days.ordered <- c(days.sorted[dofirst],
	                  days.sorted[!dofirst & is_sundaylike[days.sorted]],
	                  days.sorted[!dofirst & is_saturdaylike[days.sorted]],
	                  days.sorted[!dofirst & is_fridaylike[days.sorted]],
	                  days.sorted[!dofirst & is_workday[days.sorted] & !is_fridaylike[days.sorted]])
	for(day in days.ordered)
	{
# 		# No more jitter for the last few days
# 		if(which(day == days.ordered) > 24)
# 			jitter <- FALSE
		
		prev_day   <- day - 1
		next_day   <- day + 1
		p_prev_day <- day - 2
		n_next_day <- day + 2
		
		date <- dates[day]
		p_prev_date <- date - 2
		n_next_date <- date + 2
		
		message(date, ": ", appendLF = FALSE)
		
		### find someone for either N1 or N
		doctor <- NULL
		doctors.available <- NULL
		split <- NULL
		
		
		# TODO: only on weekdays
		# TODO: resulting day presence can still be -1 if doctor from the same ward gets X *after* this
		provisional_day_presence_allowing <- rep(TRUE, length(rownames(doctors)))
		if(is_workday[day])
		{
			provisional_day_presence <- schedule[,day] != "X" & !requests[,day] %in% c("FT", day_shifts_absent, holiday_shifts)
			for (ward in levels(doctors$ward))
			{
				provisional_day_presence_allowing[doctors$ward == ward] <- sum(provisional_day_presence[doctors$ward == ward]) > wards$min_presence[ward,day]
			}
			# also forbid if resulting total presence would be < -2
			# TODO: this should not be a general rule
			provisional_day_presence_allowing <- provisional_day_presence_allowing & sum(!requests[,day] %in% c("FT", day_shifts_absent, holiday_shifts)) > sum(wards$min_presence[,day]) - 1
		}
		if(!any(provisional_day_presence_allowing))
			message("ignoring PDP: ", appendLF = FALSE)
		
		
		provisional_next_day_presence_allowing <- rep(TRUE, length(rownames(doctors)))
		if(next_day %in% days && is_workday[next_day])
		{
			provisional_next_day_presence <- schedule[,next_day] != "N2" & !requests[,next_day] %in% c("N2", "FT", day_shifts_absent, holiday_shifts)
			for (ward in levels(doctors$ward))
			{
				provisional_next_day_presence_allowing[doctors$ward == ward] <- sum(provisional_next_day_presence[doctors$ward == ward]) > wards$min_presence[ward,next_day] - 1
			}
		}
		if(!any(provisional_next_day_presence_allowing))
			message("ignoring PNDP: ", appendLF = FALSE)
		
		
		doctors.available.for.N <- schedule[,day] != "X" & requests[,day] == ""
		if(any(provisional_next_day_presence_allowing & doctors.available.for.N))
			doctors.available.for.N <- doctors.available.for.N & provisional_next_day_presence_allowing
		doctors.available.for.N <- doctors.available.for.N | requests[,day] == "N"
		
		
		doctors.available.for.N1 <- schedule[,day] != "X" & requests[,day] == "" & (doctors[,"split_shifts"] | doctors[,"shifts"] > doctors[,"shifts_target"] - 0.5)
		doctors.available.for.N1 <- doctors.available.for.N1 | requests[,day] == "N1"
		
		
		doctors.available.for.N2 <- schedule[,day] != "X" & requests[,day] == "" & (doctors[,"split_shifts"] | doctors[,"shifts"] > doctors[,"shifts_target"] - 0.5)
		doctors.available.for.N2 <- doctors.available.for.N2 & provisional_day_presence_allowing
		if(any(provisional_next_day_presence_allowing & doctors.available.for.N2))
			doctors.available.for.N2 <- doctors.available.for.N2 & provisional_next_day_presence_allowing
		doctors.available.for.N2 <- doctors.available.for.N2 | requests[,day] == "N2"
		
		
		split_possible <- is_splitday[day] && 
		                  any(doctors.available.for.N1) && 
		                  any(doctors.available.for.N2) && 
		                  sum(doctors.available.for.N1 | doctors.available.for.N2) >= 2
		
		
		N_requested <- sum(requests[,day] %in% "N") > 0
		N1_requested <- sum(requests[,day] %in% "N1") > 0
		N2_reqested <- sum(requests[,day] %in% "N2") > 0
		
		
		sort_by <- "days"
		if(!is_workday[day] || is_fridaylike[day])
			sort_by <- "weekends"
		
		
		if(N_requested || N1_requested && split_possible)
		{
			doctors.available <- schedule[,day] != "X" & requests[,day] %in% c("N", "N1")
			if(sum(doctors.available) == 0)
			{
				message("skipping day")
				warnings <- c(warnings, warning(date, ": skipping day"))
				opt_parms$n.unresolved <- opt_parms$n.unresolved + 1
				next
			}
			doctor <- pick.doctor(doctors[doctors.available,], sort_by = sort_by, jitter = jitter)
			split <- ifelse(requests[doctor, day] == "N1", TRUE, FALSE)
		} else
		{
			if(split_possible && N2_reqested)
			{
				doctors.available <- doctors.available.for.N1
			} else if(split_possible)
			{
				doctors.available <- doctors.available.for.N | doctors.available.for.N1
			} else
			{
				doctors.available <- doctors.available.for.N
			}
			if(sum(doctors.available) == 0)
			{
				message("skipping day")
				warnings <- c(warnings, warning(date, ": skipping day"))
				opt_parms$n.unresolved <- opt_parms$n.unresolved + 1
				next
			}
			doctor <- pick.doctor(doctors[doctors.available,], sort_by = sort_by, jitter = jitter)
			split <- doctors[doctor,"split_shifts"] && split_possible
			
			# in case the only doctor available for n2 is chosen for n1 -> do not split after all
			if(split && !any(doctors.available.for.N2[rownames(doctors) != doctor]))
				split <- FALSE
		}
		message(doctor, " will do ", appendLF = FALSE)
		if(split)
		{
			### assign N1
			message("N1, ", appendLF = FALSE)
			schedule[doctor,day] <- "N1"
			doctors[doctor,"shifts"] <- doctors[doctor,"shifts"] + 0.5
			doctors[doctor,"days"]   <- doctors[doctor,"days"] + 1
			doctors[doctor,"hours"]  <- doctors[doctor,"hours"] + 12.5
			
			### resulting restrictions
			if (p_prev_day %in% days && requests[doctor,p_prev_day] == "")
				requests[doctor,p_prev_day] <- "!N1"
			if (prev_day %in% days && requests[doctor,prev_day] == "")
				requests[doctor,prev_day] <- "!N"
			if (next_day %in% days && requests[doctor,next_day] == "")
				requests[doctor,next_day] <- "!N1"
			if (n_next_day %in% days && requests[doctor,n_next_day] == "")
				requests[doctor,n_next_day] <- "!N1"
			
			### find someone for N2
			doctor <- NULL
			doctors.available <- NULL
			sort_by = "nights"
			doctors.available.for.N2 <- doctors.available.for.N2 & schedule[,day] != "N1"
			if(N2_reqested)
			{
				doctors.available <- requests[,day] %in% "N2"
				doctor <- pick.doctor(doctors[doctors.available,], sort_by = sort_by, jitter = jitter)
			} else
			{
				doctors.available <- doctors.available.for.N2
				# This actually shouldn't happen
				if(sum(doctors.available) == 0)
				{
					message("skipping N2")
					warnings <- c(warnings, warning(date, ": skipping N2"))
					opt_parms$n.unresolved <- opt_parms$n.unresolved + 1
					next
				}
				doctor <- pick.doctor(doctors[doctors.available,], sort_by = sort_by, jitter = jitter)
			}
			### assign N2
			message(doctor, " will do N2")
			schedule[doctor,day] <- "N2"
			doctors[doctor,"shifts"] <- doctors[doctor,"shifts"] + 0.5
			doctors[doctor,"nights"] <- doctors[doctor,"nights"] + 1
			doctors[doctor,"hours"]  <- doctors[doctor,"hours"] + 4
			if(is_fridaylike[day])
				doctors[doctor,"weekends"] <- doctors[doctor,"weekends"] + 0.4
			if(next_day %in% days && schedule[doctor,next_day] == "")
			{
				schedule[doctor,next_day] <- "X"
				doctors[doctor,"hours"]  <- doctors[doctor,"hours"] + 8.5
			}
			
			### resulting restrictions
# 			if (p_prev_day %in% days && requests[doctor,p_prev_day] == "")
# 				requests[doctor,p_prev_day] <- "!N"
			if (prev_day %in% days && requests[doctor,prev_day] == "")
				requests[doctor,prev_day] <- "!N2"
# 			if (next_day %in% days && requests[doctor,next_day] == "")
# 				requests[doctor,next_day] <- "!N"
# 			if (n_next_day %in% days && requests[doctor,n_next_day] == "")
# 				requests[doctor,n_next_day] <- "!N"
		} else
		{
			### assign N
			message("N")
			schedule[doctor,day] <- "N"
			doctors[doctor,"shifts"] <- doctors[doctor,"shifts"] + 1
			doctors[doctor,"days"]   <- doctors[doctor,"days"] + 1
			doctors[doctor,"nights"] <- doctors[doctor,"nights"] + 1
			doctors[doctor,"hours"]  <- doctors[doctor,"hours"] + 16
			if(is_fridaylike[day])
				doctors[doctor,"weekends"] <- doctors[doctor,"weekends"] + 0.4
			if(is_saturdaylike[day])
				doctors[doctor,"weekends"] <- doctors[doctor,"weekends"] + 1
			if(is_sundaylike[day])
				doctors[doctor,"weekends"] <- doctors[doctor,"weekends"] + 0.6
			
			if(next_day %in% days && schedule[doctor,next_day] == "")
			{
				schedule[doctor,next_day] <- "X"
				doctors[doctor,"hours"]  <- doctors[doctor,"hours"] + 9
			}
			
			
# 			# Make a positive request for a friday_sunday combination
# 			#TODO: this is old, see if it is still correct
# 			n.shifts_or_requests <- sum(requests[doctor,] == "N" | schedule[doctor,] == "N") + sum(requests[doctor,] %in% c("N1", "N2") | schedule[doctor,] %in% c("N1", "N2") / 2)
# 			if(doctors[doctor,"friday_sunday"] && n.shifts_or_requests <= doctors[doctor,"shifts_target"] - 1)
# 			{
# 				if(is_fridaylike[day] && n_next_day %in% days && is_sundaylike[n_next_day])
# 				{
# 					if(sum(requests[,n_next_day] == "N") == 0 && requests[doctor,n_next_day] == "")
# 						requests[doctor,n_next_day] <- "N"
# 				} else
# 				if(is_sundaylike[day] && p_prev_day %in% days && is_fridaylike[p_prev_day])
# 				{
# 					if(sum(requests[,p_prev_day] == "N") == 0 && requests[doctor,p_prev_day] == "")
# 						requests[doctor,p_prev_day] <- "N"
# 				}
# 			}
			
			
			### resulting restrictions
			if (p_prev_day %in% days && requests[doctor,p_prev_day] == "")
				requests[doctor,p_prev_day] <- "!N1"
			if (prev_day %in% days && requests[doctor,prev_day] == "")
				requests[doctor,prev_day] <- "!N"
# 			if (next_day %in% days && requests[doctor,next_day] == "")
# 				requests[doctor,next_day] <- "!N"
			if (n_next_day %in% days && requests[doctor,n_next_day] == "")
				requests[doctor,n_next_day] <- "!N1"
			
			
			# undo the above in case of friday-sunday - this allows friday-sunday, but does not actively request it
			#TODO: fix above again, then remove this
			if(doctors[doctor,"friday_sunday"])
			{
				if(is_fridaylike[day] && n_next_day %in% days && is_sundaylike[n_next_day] && requests.orig[doctor,n_next_day] == "")
					requests[doctor,n_next_day] <- ""
				if(is_sundaylike[day] && p_prev_day %in% days && is_fridaylike[p_prev_day] && requests.orig[doctor,p_prev_day] == "")
					requests[doctor,p_prev_day] <- ""
			}
			
			
			# Request surrounding weekends free
			if(is_friday[day])
			{
				if((day + 7) %in% days && requests[doctor, day + 7] == "")
					requests[doctor, day + 7] <- "!N"
				if((day + 8) %in% days && requests[doctor, day + 8] == "")
					requests[doctor, day + 8] <- "!N"
# 				if((day + 9) %in% days && requests[doctor, day + 9] == "")
# 					requests[doctor, day + 9] <- "!N"
				if((day - 5) %in% days && requests[doctor, day - 5] == "")
					requests[doctor, day - 5] <- "!N"
				if((day - 6) %in% days && requests[doctor, day - 6] == "")
					requests[doctor, day - 6] <- "!N"
				if((day - 7) %in% days && requests[doctor, day - 7] == "")
					requests[doctor, day - 7] <- "!N"
			}
			if(is_saturday[day])
			{
				if((day + 6) %in% days && requests[doctor, day + 6] == "")
					requests[doctor, day + 6] <- "!N"
				if((day + 7) %in% days && requests[doctor, day + 7] == "")
					requests[doctor, day + 7] <- "!N"
				if((day + 8) %in% days && requests[doctor, day + 8] == "")
					requests[doctor, day + 8] <- "!N"
				if((day - 6) %in% days && requests[doctor, day - 6] == "")
					requests[doctor, day - 6] <- "!N"
				if((day - 7) %in% days && requests[doctor, day - 7] == "")
					requests[doctor, day - 7] <- "!N"
				if((day - 8) %in% days && requests[doctor, day - 8] == "")
					requests[doctor, day - 8] <- "!N"
			}
			if(is_sunday[day])
			{
				if((day + 5) %in% days && requests[doctor, day + 5] == "")
					requests[doctor, day + 5] <- "!N"
				if((day + 6) %in% days && requests[doctor, day + 6] == "")
					requests[doctor, day + 6] <- "!N"
				if((day + 7) %in% days && requests[doctor, day + 7] == "")
					requests[doctor, day + 7] <- "!N"
				if((day - 7) %in% days && requests[doctor, day - 7] == "")
					requests[doctor, day - 7] <- "!N"
				if((day - 8) %in% days && requests[doctor, day - 8] == "")
					requests[doctor, day - 8] <- "!N"
# 				if((day - 9) %in% days && requests[doctor, day - 9] == "")
# 					requests[doctor, day - 9] <- "!N"
			}
		}
	}
	doctors$shifts_carryover   <- doctors$shifts   - doctors$shifts_target
	doctors$weekends_carryover <- doctors$weekends - doctors$weekends_target
	
	#################################################################################################
	#################################################################################################
	workdays <- days[is_workday]
	
	### preliminary - grant all day requests #######################################################
	
# 	schedule[requests %in% day_shifts] <- requests[requests %in% day_shifts]
	# TODO:
	requests.restoreddayrequests <- strip.requests(requests.orig, hardmode = FALSE)
	mask <- requests.restoreddayrequests %in% c(day_shifts, day_shifts_absent) & schedule %in% ""
	schedule[mask] <- requests.restoreddayrequests[mask]
	
	### preliminary - update stats #################################################################
	
	doctors$hours <- rowSums(as.hours(schedule))
	
	for(ward in rownames(wards$hours))
	{
		day_hours <- as.day_hours(schedule[doctors$ward == ward,])
		if(is.matrix(day_hours))
			day_hours <- colSums(day_hours)
		wards$hours[ward,] <- day_hours
		
		day_presence <- as.day_hours(schedule[doctors$ward == ward,]) != 0
		if(is.matrix(day_presence))
			day_presence <- colSums(day_presence) else
			day_presence <- as.numeric(day_presence)
		wards$presence[ward,] <- day_presence
	}
	
	### preliminary - FTs #############################################################
	saturdays <- days[is_saturday]
	for(saturday in saturdays)
	{
		doctors.concerned <- schedule[,saturday] %in% "N"
		if((saturday - 1) %in% days && (saturday + 1) %in% days)
		doctors.concerned <- doctors.concerned | 
		                     schedule[,saturday - 1] %in% "N" & 
		                     schedule[,saturday + 1] %in% "N"
		for(doctor in rownames(doctors)[doctors.concerned])
		{
			weekdays <- seq(from=saturday - 1, to=saturday - 5, by=-1)
			weekdays <- weekdays[weekdays %in% days]
			weekdays <- weekdays[!is_holiday[weekdays]]
			if(any(schedule[doctor,weekdays] == "FT"))
				next
			weekdays <- weekdays[schedule[doctor,weekdays] == ""]
			if(length(weekdays) == 0)
				next  #TODO: some message here
			# Find day with least absences on the ward
			ward <- as.character(doctors[doctor,"ward"])
			if(length(weekdays) > 1)
			{
				total_day_presence.subset <- schedule[,weekdays] != "FT" & schedule[,weekdays] != "X" & schedule[,weekdays] != "N2" & !schedule[,weekdays] %in% c(day_shifts_absent, holiday_shifts)
				day_presence.subset <- total_day_presence.subset[doctors[,"ward"] == ward,]
				if(!is.null(dim(total_day_presence.subset)))
					total_day_presence.subset <- colSums(total_day_presence.subset)
				if(!is.null(dim(day_presence.subset)))
					day_presence.subset <- colSums(day_presence.subset)
				total_min_presence.subset <- colSums(wards$min_presence[,weekdays])
				min_presence.subset <- wards$min_presence[ward,weekdays]
				sortfirst <- total_min_presence.subset - total_day_presence.subset
				sortlast <- min_presence.subset - day_presence.subset
				weekdays <- weekdays[sort(sortfirst, index.return = TRUE)$ix]
				weekdays <- weekdays[sort(sortlast[sort(sortfirst, index.return = TRUE)$ix], index.return = TRUE)$ix]
			}
			weekday <- weekdays[1]
			schedule[doctor,weekday] <- "FT"
		}
	}
	
# 	### iteration 0 - fixed long days #########################################
# 	workdays.shuffled <- sample(workdays)
# 	for(day in workdays.shuffled)
# 	{
# 		if("8" %in% schedule[,day])
# 			next
# 		date <- dates[day]
# 		message(date, ": ", appendLF = FALSE)
# 		doctors.available <- doctors[,"hours"] < doctors[,"hours_max_work"] &
# 		                     schedule[,day] == ""
# 		if(sum(doctors.available) == 0)
# 		{
# 			message("no doctor")
# 			warnings <- c(warnings, warning("No more doctor found for ", day, " presence remains ", "asdf"))
# 			next
# 		}
# 		doctor <- pick.doctor(doctors[doctors.available,], sort_by = "hours")
# 		
# 		### assign 8
# 		message("assigning ", doctor, " to 8h")
# 		schedule[doctor,day] <- "8"
# 		doctors[doctor,"hours"] <- doctors[doctor,"hours"] + 8
# 		ward <- as.character(doctors[doctor,"ward"]) #TODO: ward was factor, caused error in the next line when interpreted as numeric - any more problems like this?
# 		wards$presence[ward,day] <- wards$presence[ward,day] + 1
# 		wards$hours[ward,day] <- wards$hours[ward,day] + 8
# 	}
	
	### iteration 1 - ward min presence #########################################
	for(ward in rownames(wards$min_presence))
	{
		workdays.shuffled <- sample(workdays)
		while(length(workdays.shuffled) > 0 && 
		      any(wards$presence[ward,workdays.shuffled] < wards$min_presence[ward,workdays.shuffled]) && 
		      any(doctors[doctors$ward == ward,"hours"] <= doctors[doctors$ward == ward,"hours_max_work"]))
		{
			workdays.sorted <- workdays.shuffled[sort(wards$presence[ward,workdays.shuffled] - wards$min_presence[ward,workdays.shuffled], index.return = TRUE)$ix]
			day <- workdays.sorted[1]
			date <- dates[day]
# 			message(date, ": ", ward, ": ", appendLF = FALSE)
			doctors.available <- doctors[,"ward"] == ward &
			                     doctors[,"hours"] < doctors[,"hours_max_work"] &
			                     schedule[,day] == ""
			if(sum(doctors.available) == 0)
			{
# 				message("no doctor")
				warnings <- c(warnings, warning("No more doctor found for ", day, ", ward ", ward, " presence remains ", wards$presence[ward,day]))
				workdays.shuffled <- workdays.shuffled[!workdays.shuffled == day]
				next
			}
			doctor <- pick.doctor(doctors[doctors.available,], sort_by = "hours")
			
			### assign 5
# 			message("assigning ", doctor, " to 5h")
			schedule[doctor,day] <- "5"
			doctors[doctor,"hours"] <- doctors[doctor,"hours"] + 5
			wards$presence[ward,day] <- wards$presence[ward,day] + 1
			wards$hours[ward,day] <- wards$hours[ward,day] + 5
		}
	}
	
	### iteration 2 - total min presence - compensate for other wards #############################
	workdays.shuffled <- sample(workdays)
	total_day_presence <- colSums(wards$presence)
	total_day_min_presence <- colSums(wards$min_presence)
	while(length(workdays.shuffled) > 0 && 
	      any(total_day_presence[workdays.shuffled] < total_day_min_presence[workdays.shuffled]) && 
	      any(doctors[,"hours"] <= doctors[,"hours_max_work"]))
	{
		workdays.sorted <- workdays.shuffled[sort(total_day_presence[workdays.shuffled] - total_day_min_presence[workdays.shuffled], index.return = TRUE)$ix]
		day <- workdays.sorted[1]
		date <- dates[day]
# 		message(date, ": ", appendLF = FALSE)
		doctors.available <- doctors[,"hours"] < doctors[,"hours_max_work"] &
		                     schedule[,day] == ""
		if(sum(doctors.available) == 0)
		{
# 			message("no doctor")
			warnings <- c(warnings, warning("No more doctor found for ", day, ", total presence remains ", sum(wards$presence[,day])))
			workdays.shuffled <- workdays.shuffled[!workdays.shuffled == day]
			next
		}
		doctor <- pick.doctor(doctors[doctors.available,], sort_by = "hours")
		
		### assign 5
# 		message("assigning ", doctor, " to 5h")
		schedule[doctor,day] <- "5"
		doctors[doctor,"hours"] <- doctors[doctor,"hours"] + 5
		ward <- as.character(doctors[doctor,"ward"])
		wards$presence[ward,day] <- wards$presence[ward,day] + 1
		wards$hours[ward,day] <- wards$hours[ward,day] + 5
	}
	
	### iteration 3 - doctor min hours #########################################
	for(ward in rownames(wards$min_presence))
	{
		workdays.shuffled <- sample(workdays)
		while(length(workdays.shuffled) > 0 && 
		      any(doctors[doctors$ward == ward,"hours"] <= doctors[doctors$ward == ward,"hours_min_work"]))
		{
			workdays.sorted <- workdays.shuffled[sort(wards$presence[ward,workdays.shuffled] - wards$min_presence[ward,workdays.shuffled], index.return = TRUE)$ix]
			day <- workdays.sorted[1]
			date <- dates[day]
# 			message(date, ": ", ward, ": ", appendLF = FALSE)
			doctors.available <- doctors[,"ward"] == ward &
			                     doctors[,"hours"] < doctors[,"hours_min_work"] &
			                     schedule[,day] == ""
			if(sum(doctors.available) == 0)
			{
# 				message("no doctor")
# 				warnings <- c(warnings, warning("No more doctor found for ", date, ", ward ", ward, " presence remains ", wards$presence[ward,day]))
				workdays.shuffled <- workdays.shuffled[!workdays.shuffled == day]
				next
			}
			doctor <- pick.doctor(doctors[doctors.available,], sort_by = "hours")
			
			### assign 5h-days
# 			message("assigning ", doctor, " to 5h")
			schedule[doctor,day] <- "5"
			doctors[doctor,"hours"] <- doctors[doctor,"hours"] + 5
			wards$presence[ward,day] <- wards$presence[ward,day] + 1
			wards$hours[ward,day] <- wards$hours[ward,day] + 5
		}
	}
	
	### iteration 4 - doctor min hours - long days #####################################
	for(ward in rownames(wards$min_presence))
	{
		workdays.shuffled <- sample(workdays)
		while(length(workdays.shuffled) > 0 && 
		      any(doctors[doctors$ward == ward,"hours"] <= doctors[doctors$ward == ward,"hours_min_work"]))
		{
			workdays.sorted <- workdays.shuffled[sort(wards$presence[ward,workdays.shuffled] - wards$min_presence[ward,workdays.shuffled], index.return = TRUE)$ix]
			day <- workdays.sorted[1]
			date <- dates[day]
			# TODO: this is horribly stacked
			doctors.available <- doctors[,"ward"] == ward &
			                     doctors[,"hours"] < doctors[,"hours_min_work"] &
			                     !requests[,day] %in% day_shifts &
			                     (schedule[,day] == "" | schedule[,day] %in% day_shifts & 
			                                             as.hours(schedule[,day]) < doctors[,"long_day_hours"] &
			                                             (!requests[,day] %in% day_requests | as.hours(schedule[,day]) < as.hours(requests[,day])))
			if(sum(doctors.available) == 0)
			{
# 				warnings <- c(warnings, warning("No more doctor found for ", date, ", ward ", ward, " hours remain ", wards$hours[ward,day]))
				workdays.shuffled <- workdays.shuffled[!workdays.shuffled == day]
# 				message("ward ", ward, ": no more doctor for ", date)
				next
			}
			doctor <- pick.doctor(doctors[doctors.available,], sort_by = "hours")
			
			### assign long days
			new_hours <- doctors[doctor,"long_day_hours"]
			previous_hours <- ifelse(schedule[doctor,day] %in% c("5", "6", "7"), as.numeric(schedule[doctor,day]), 0)
			schedule[doctor,day] <- as.character(new_hours)
			doctors[doctor,"hours"] <- doctors[doctor,"hours"] -previous_hours + new_hours
			wards$presence[ward,day] <- wards$presence[ward,day] + ifelse(previous_hours == 0, 1, 0)
			wards$hours[ward,day] <- wards$hours[ward,day] -previous_hours + new_hours
# 			message("ward ", ward, ": added/upped ", doctor, " on ", day)
		}
	}
	
	### iteration 5 - doctor min hours - 8h-days #####################################
	# TODO: redo this
	for(ward in rownames(wards$min_presence))
	{
		workdays.shuffled <- sample(workdays)
		while(length(workdays.shuffled) > 0 && 
		      any(doctors[doctors$ward == ward,"hours"] <= doctors[doctors$ward == ward,"hours_min_work"]))
		{
			workdays.sorted <- workdays.shuffled[sort(wards$presence[ward,workdays.shuffled] - wards$min_presence[ward,workdays.shuffled], index.return = TRUE)$ix]
			day <- workdays.sorted[1]
			date <- dates[day]
			# TODO: this is horribly stacked
			doctors.available <- doctors[,"ward"] == ward &
			                     doctors[,"hours"] < doctors[,"hours_min_work"] &
			                     !requests[,day] %in% day_shifts &
			                     (schedule[,day] == "" | schedule[,day] %in% day_shifts & 
			                                             as.hours(schedule[,day]) < 8 &
			                                             (!requests[,day] %in% day_requests | as.hours(schedule[,day]) < as.hours(requests[,day])))
			if(sum(doctors.available) == 0)
			{
# 				warnings <- c(warnings, warning("No more doctor found for ", date, ", ward ", ward, " hours remain ", wards$hours[ward,day]))
				workdays.shuffled <- workdays.shuffled[!workdays.shuffled == day]
# 				message("ward ", ward, ": no more doctor for ", date)
				next
			}
			doctor <- pick.doctor(doctors[doctors.available,], sort_by = "hours")
			
			### assign 8h-days
			new_hours <- 8
			previous_hours <- ifelse(schedule[doctor,day] %in% c("5", "6", "7"), as.numeric(schedule[doctor,day]), 0)
			schedule[doctor,day] <- as.character(new_hours)
			doctors[doctor,"hours"] <- doctors[doctor,"hours"] -previous_hours + new_hours
			wards$presence[ward,day] <- wards$presence[ward,day] + ifelse(previous_hours == 0, 1, 0)
			wards$hours[ward,day] <- wards$hours[ward,day] -previous_hours + new_hours
# 			message("ward ", ward, ": added/upped ", doctor, " on ", day)
		}
	}
	
	#
	schedule[,workdays][schedule[,workdays] == ""] <- "-"
	
	
	doctors$weekhours_work <- doctors$hours * 40 / doctors$hours_min_work
	
	request_counts <- count.requests.granted(requests = requests.orig, schedule = schedule)
	doctors$requests_granted <- request_counts$requests_granted
	doctors$requests_denied <- request_counts$requests_denied
	doctors$soft_requests_granted <- request_counts$soft_requests_granted
	doctors$soft_requests_denied <- request_counts$soft_requests_denied
	
	### post-hoc: collect optimization parameters ##################################################
	
	opt_parms$n.requests_denied <- sum(doctors$requests_denied)
	
	
	opt_parms$n.soft_requests_granted <- sum(doctors$soft_requests_granted)
	opt_parms$n.soft_requests <- opt_parms$n.soft_requests_granted + sum(doctors$soft_requests_denied)
	
	
	range <- range(doctors$shifts_carryover)
	opt_parms$range.shifts <- range[2] - range[1]
	
	
	range <- range(doctors$weekends_carryover)
	opt_parms$range.weekends <- range[2] - range[1]
	
	
	opt_parms$range.nights <- max(abs(doctors$nights - doctors$days))
	
	
	#TODO: make sure this is never > 1?
	opt_parms$n.split <- sum(schedule %in% "N1")
	opt_parms$n.splittable <- sum(is_splitday)
	
	
	day_unit <- 5
	wards$presence <- wards$hours / day_unit
	wards$presence_missing <- wards$min_presence - wards$presence
	for(i in seq_along(wards$presence_missing))
	{
		wards$presence_missing[i] <- max(0, wards$presence_missing[i])
	}
	# TODO: this^2 makes an unintuitive value, but is necessary for punishment of outliers
	opt_parms$day_presence_missing <- sum(colSums(wards$presence_missing))
	opt_parms$day_presence_missing.squared <- sum(colSums(wards$presence_missing ^ 2))
	
	
	return(list(doctors = doctors, 
	            requests = requests, 
	            schedule = schedule, 
	            wards = wards, 
	            opt_parms = opt_parms,
	            warnings = warnings))
}




optimal.schedule <- function(doctors = read.doctors(), requests = read.requests(), wards = read.wards(), n.iterations = 100, weights = list(soft_requests = 0.5, r.shifts = 2, r.weekends = 2, r.nights = 2, n.split = 0.5, day_presence = 1))
{
	message("Optimizing - trying ", n.iterations, " variations...")
	message("n.unres n.rq_den n.srq_granted r.shifts r.weekends r.nights n.split day_presence")
	out <- NULL
	i <- 0
	while(i < n.iterations)
	{
		hardmode <- runif(1, min = 0, max = 1)
		jitter <- runif(1, min = 0, max = 1)
# 		hardmode <- FALSE
		jitter <- FALSE
		out1 <- suppressMessages(create.schedule(doctors = doctors, 
		                                         requests = requests, 
		                                         wards = wards, 
		                                         hardmode = hardmode,
		                                         jitter = jitter))
		
		# This is the factor that we'll optimize for (lower is better)
		# The additive values determine the weight of the factor (and grant that the product doesn't zero out)
		# TODO: normalize these somehow and put them on a quadratic function or something that punishes outliers
		out1$optimization_factor <- (out1$opt_parms$n.unresolved + 0.001) *
		                            (out1$opt_parms$n.requests_denied + 0.001) *
		                            (1 - ifelse(out1$opt_parms$n.soft_requests == 0, 1, out1$opt_parms$n.soft_requests_granted / out1$opt_parms$n.soft_requests) + 0.01) ^ weights$soft_requests *
		                            (max(0.5, out1$opt_parms$range.shifts) + 0.01) ^ weights$r.shifts *
		                            (max(0.5, out1$opt_parms$range.weekends) + 0.01) ^ weights$r.weekends *
		                            (max(0.5, out1$opt_parms$range.nights) + 0.01) ^ weights$r.nights *
		                            (1 - out1$opt_parms$n.split / out1$opt_parms$n.splittable + 0.01) ^ weights$n.split *
		                            (out1$opt_parms$day_presence_missing.squared + 0.01) ^ weights$day_presence
		
		if(i == 0)
		{
			out <- out1
		}
		          
		if(out1$optimization_factor <= out$optimization_factor)
		{
			out <- out1
			message(formatC(out$opt_parms$n.unresolved, width = 7), 
			        formatC(out$opt_parms$n.requests_denied, width = 9), 
			        formatC(sprintf("%.f/%.f", out$opt_parms$n.soft_requests_granted, out$opt_parms$n.soft_requests), width = 14), 
			        formatC(out$opt_parms$range.shifts, width = 9), 
			        formatC(out$opt_parms$range.weekends, width = 11), 
			        formatC(out$opt_parms$range.nights, width = 9), 
			        formatC(sprintf("%.f/%.f", out$opt_parms$n.split, out$opt_parms$n.splittable), width = 8), 
			        formatC(sprintf("%.1f (%.1f)", out$opt_parms$day_presence_missing, out$opt_parms$day_presence_missing.squared), width = 13))
		}
		
		
		i <- i + 1
	}
	return(out)
}




# optimal.schedule.both <- function(doctors = read.doctors(), requests = read.requests(), wards = read.wards(), n.iterations = 100)
# {
# 	doctors.FA <- subset(doctors, role == "FA")
# 	doctors.AA <- subset(doctors, role == "AA")
# 	requests.FA <- requests[doctors$role == "FA",]
# 	requests.AA <- requests[doctors$role == "AA",]
# 	wards.FA <- strip.wards(wards, subset = "FA")
# 	wards.AA <- strip.wards(wards, subset = "AA")
# 	
# 	out.FA <- optimal.schedule(doctors = doctors.FA, requests = requests.FA, wards = wards.FA, n.iterations = n.iterations)
# 	doctors.FA                 <- out.FA$doctors
# 	requests.FA                <- out.FA$requests
# 	schedule.FA                <- out.FA$schedule
# 	wards.FA                   <- out.FA$wards
# 	opt_parms.FA <- out.FA$opt_parms
# 	warnings.FA                <- out.FA$warnings
# 	
# 	# make AA compensate for missing FA
# 	day_presence_missing.FA <- wards.FA$presence - wards.FA$min_presence
# 	day_presence_missing.FA[day_presence_missing.FA > 0] <- 0
# 	wards.AA$min_presence <- wards.AA$min_presence - day_presence_missing.FA
# 	
# 	out.AA <- optimal.schedule(doctors = doctors.AA, requests = requests.AA, wards = wards.AA, n.iterations = n.iterations)
# 	doctors.AA                 <- out.AA$doctors
# 	requests.AA                <- out.AA$requests
# 	schedule.AA                <- out.AA$schedule
# 	wards.AA                   <- out.AA$wards
# 	opt_parms.AA <- out.AA$opt_parms
# 	warnings.AA                <- out.AA$warnings
# 	
# 	doctors  <- rbind(doctors.FA, doctors.AA)[rownames(doctors),]
# 	requests <- rbind(requests.FA, requests.AA)[rownames(requests),]
# 	schedule <- rbind(schedule.FA, schedule.AA)[rownames(requests),]
# 	wards$presence    <- wards.FA$presence + wards.AA$presence
# 	wards$presence.FA <- wards.FA$presence
# 	wards$presence.AA <- wards.AA$presence
# 	wards$hours    <- wards.FA$hours + wards.AA$hours
# 	wards$hours.FA <- wards.FA$hours
# 	wards$hours.AA <- wards.AA$hours
# 	opt_parms <- NULL #TODO
# 	warnings <- c(warnings.FA, warnings.AA)
# 	
# 	return(list(doctors = doctors, 
# 	            requests = requests, 
# 	            schedule = schedule, 
# 	            wards = wards, 
# 	            opt_parms = opt_parms,
# 	            warnings = warnings))
# }



