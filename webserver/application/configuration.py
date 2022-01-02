## DATABASE
DB_HOST = 'localhost'  # DB server address
DB_PORT = 3306  # DB server port
DB_USER = 'root'  # DB server user
DB_PASSWORD = 'root'  # DB server password
DB = "Pandore"  # DB name

#NUTRISCORE
NUTRISCORE_REFERENCE_FREQUENCY = 1/0.05 # 1 / time in second between two requests
NUTRISCORE_REFERENCE_DEBIT = 0.1        # exchange debit (in MB/s)
NUTRISCORE_REFERENCE_DIVERSITY = 50     # number of distincts servers
NUTRISCORE_WEIGHT_FREQUENCY = 1/3
NUTRISCORE_WEIGHT_DEBIT = 1/3
NUTRISCORE_WEIGHT_DIVERSITY = 1/3
SIGMOIDE_SLOPE = 1                      # slope of the sigmoide

