# install.packages("xlsx")
source("../doctor_scheduling.R")

start_date <- as.Date("2019-02-01")
end_date   <- as.Date("2019-02-28")
doctors <- read.doctors("doctors.xlsx")
write.template(start_date = start_date, end_date = end_date, doctors = doctors)
