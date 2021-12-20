# PANDORE AGENT CONFIG

## NETWORK
AUDITED_INTERFACE = "Ethernet 2"  # Interface to sniff
DEVICE_NETWORK = "192.168.1.0/24"  # Audited device network (use in filter)

## CUSTOM FILTER
CUSTOM_FILTER = "not port 1194 and not port 3306"

## DATABASE
DB_HOST = '192.168.100.10'  # DB server address
DB_PORT = 3306  # DB server port
DB_USER = 'root'  # DB server user
DB_PASSWORD = 'my-secret-pw'  # DB server password
DB = "Pandore"  # DB name

## CAPTURE CONFIG
CAPTURE_NAME = "capture"  # The name of the capture
CAPTURE_DURATION = 60  # The duration of the capture in second
CAPTURE_DESCRIPTION = "description test"  # The description of the capture
CAPTURE_CNX_TYPE = "Cable-pc"  # A description of the interface used
