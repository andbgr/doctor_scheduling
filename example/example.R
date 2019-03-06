# DESCRIPTION:
# Creates a doctors' schedule ("Dienstplan") for a group of doctors in a 
# department, assigning one 25h shift (or 2 12.5h shifts) each day, and 
# assigning normal day shifts for the other doctors. Takes as input a list of 
# doctors with general preferences, a schedule with their constraints 
# (see below), and a schedule with desired ward day presence. Tries to optimize 
# for balance (number of shifts, number of weekend shifts, etc) and day presence
# on the wards.


# install.packages("xlsx")
source("../doctor_scheduling.R")


start_date <- as.Date("2019-02-01")
end_date   <- as.Date("2019-02-28")
doctors <- read.doctors("doctors.xlsx")
write.template(start_date = start_date, end_date = end_date, doctors = doctors)


# ...NOW GO AND EDIT input.xlsx


input <- read.input("input.xlsx", doctors = doctors)
requests <- input$requests
wards    <- input$wards


# CREATE ONE SCHEDULE
# out <- create.schedule(doctors = doctors, requests = requests, wards = wards)


# CREATE OPTIMAL SCHEDULE
# this will take time, on my system (Core i3 from 2015) it takes 1h for about 7000 iterations

# OPTIMIZATION PARAMETERS:
# n.unres          number of unresolved days - should be 0
# n.rq_den         number of requests denied - should be 0 unless there are conflicting requests (like 2 positive requests on the same day)
# n.srq_granted    number of soft "would be nice" requests srq_granted
# r.shifts         range of deviations of number of shifts from shifts target (example: arithmetic target number is 3.5 shifts per doctor, some get 3, some get 4, then r.shifts would be 1)
# r.weekends       like above, only for weekends. currently, a saturday counts as 1 weekend, friday 0.4, sunday 0.6
# r.nights         maximum discrepancy of nights vs days in one doctor (for 12.5h shifts)
# n.split          how many shifts could be split (i.e. 12.5h) - more is better
# day_presence     number of doctordays missing to reach ward day presence specified in wards.min_presence.csv

# WEIGHTS:
# how to weigh the different optimization parameters - higher is more important, 0 is disregard completely - TRY OUT DIFFERENT VALUES!

system.time(
out <- optimal.schedule(doctors = doctors, requests = requests, wards = wards, 
                        n.iterations = 7000, weights = list(soft_requests = 0.5, 
                                                            r.shifts = 2, 
                                                            r.weekends = 2, 
                                                            r.nights = 2, 
                                                            n.split = 1, 
                                                            day_presence = 2))
)


doctors                 <- out$doctors
schedule                <- out$schedule
wards                   <- out$wards
opt_parms               <- out$opt_parms
warnings                <- out$warnings

write.schedule(doctors = doctors, schedule = schedule, wards = wards, opt_parms = opt_parms, warnings = warnings)
