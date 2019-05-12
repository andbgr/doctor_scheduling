# install.packages("xlsx")
source("../doctor_scheduling.R")

doctors <- read.doctors("doctors.xlsx")
input   <- read.input("input.xlsx", doctors = doctors)
requests <- input$requests
wards    <- input$wards


# CREATE ONE SCHEDULE
# out <- create.schedule(doctors = doctors, requests = requests, wards = wards)


# CREATE OPTIMAL SCHEDULE
# this will take time, on my system (Core i3 from 2015) it takes 1h for about 7000 iterations
system.time(
out <- optimal.schedule(doctors = doctors, requests = requests, wards = wards, 
                        n.iterations = 7000, weights = list(soft_requests = 1, 
                                                            r.shifts = 2, 
                                                            r.weekends = 2, 
                                                            r.nights = 1, 
                                                            n.split = 1, 
                                                            day_presence = 1))
)


doctors                 <- out$doctors
schedule                <- out$schedule
wards                   <- out$wards
opt_parms               <- out$opt_parms
warnings                <- out$warnings

write.schedule(doctors = doctors, schedule = schedule, wards = wards, opt_parms = opt_parms, warnings = warnings)
