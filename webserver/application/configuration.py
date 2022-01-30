import os

## DATABASE
DB_HOST = os.environ['PW_DB_HOST'] if "PW_DB_HOST" in os.environ else "localhost"  # DB server address
DB_PORT = os.environ['PW_DB_PORT'] if "PW_DB_PORT" in os.environ else 3306  # DB server port
DB_USER = os.environ['PW_DB_USER'] if "PW_DB_USER" in os.environ else 'root'  # DB server user
DB_PASSWORD = os.environ['PW_DB_PASSWORD'] if "PW_DB_PASSWORD" in os.environ else 'root'  # DB server password
DB = os.environ['PW_DB_NAME'] if "PW_DB_NAME" in os.environ else "Pandore"  # DB name