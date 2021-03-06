from datetime import datetime
from application.models import *

class PandoreCapture():

    ID: int
    Name: str
    StartTime: datetime
    EndTime: datetime
    Description: str
    Interface: str
    ConnectionType: str
    InactivityTimeout: int

    def __init__(self, ID: int, Name: str, StartTime: datetime, EndTime: datetime, Description: str, Interface: str, ConnectionType: str, InactivityTimeout: int) -> None:
        self.ID = ID
        self.Name = Name
        self.StartTime = StartTime
        self.EndTime = EndTime
        self.Description = Description
        self.Interface = Interface
        self.ConnectionType = ConnectionType
        self.InactivityTimeout = InactivityTimeout

class PandoreConfiguration():

    NUTRISCORE_REFERENCE_FREQUENCY: int
    NUTRISCORE_REFERENCE_DEBIT: float
    NUTRISCORE_REFERENCE_DIVERSITY: int
    NUTRISCORE_WEIGHT_FREQUENCY: int
    NUTRISCORE_WEIGHT_DEBIT: int
    NUTRISCORE_WEIGHT_DIVERSITY: int
    NUTRISCORE_SIGMOIDE_SLOPE: float
    NUTRISCORE_AVERAGE_TYPE: int
    SNIFFER_API_ADDRESS: str

    def __init__(self, NUTRISCORE_REFERENCE_FREQUENCY: int, NUTRISCORE_REFERENCE_DEBIT: float, NUTRISCORE_REFERENCE_DIVERSITY: int, NUTRISCORE_WEIGHT_FREQUENCY: int, NUTRISCORE_WEIGHT_DEBIT: int, NUTRISCORE_WEIGHT_DIVERSITY: int, NUTRISCORE_SIGMOIDE_SLOPE: float, NUTRISCORE_AVERAGE_TYPE: int, SNIFFER_API_ADDRESS: str) -> None:
        self.NUTRISCORE_REFERENCE_FREQUENCY = NUTRISCORE_REFERENCE_FREQUENCY
        self.NUTRISCORE_REFERENCE_DEBIT = NUTRISCORE_REFERENCE_DEBIT
        self.NUTRISCORE_REFERENCE_DIVERSITY = NUTRISCORE_REFERENCE_DIVERSITY
        self.NUTRISCORE_WEIGHT_FREQUENCY = NUTRISCORE_WEIGHT_FREQUENCY
        self.NUTRISCORE_WEIGHT_DEBIT = NUTRISCORE_WEIGHT_DEBIT
        self.NUTRISCORE_WEIGHT_DIVERSITY = NUTRISCORE_WEIGHT_DIVERSITY
        self.NUTRISCORE_SIGMOIDE_SLOPE = NUTRISCORE_SIGMOIDE_SLOPE
        self.NUTRISCORE_AVERAGE_TYPE = NUTRISCORE_AVERAGE_TYPE
        self.SNIFFER_API_ADDRESS = SNIFFER_API_ADDRESS

class PandoreService():

    ID: int
    Name: str

    def __init__(self, ID: int, Name: str) -> None:
        self.ID = ID
        self.Name = Name

class PandoreServiceKeyword():
    ID: int
    Value: str
    Service: PandoreService

    def __init__(self, ID: int, Value: int, Service: PandoreService) -> None:
        self.ID = ID
        self.Value = Value
        self.Service = Service

class PandoreDNS():

    ID: int
    Value: str
    Service: PandoreService

    def __init__(self, ID: int, Value: str, Service: PandoreService) -> None:
        self.ID = ID
        self.Value = Value
        self.Service = Service

class PandoreServer():

    ID: int
    Address: str
    DNS: PandoreDNS

    def __init__(self, ID: int, Address: str, DNS: PandoreDNS) -> None:
        self.ID = ID
        self.Address = Address
        self.DNS = DNS

class PandoreCaptureRequest():

    ID: int
    PascketSize: int
    Direction: bool
    DateTime: datetime
    Protocol: str
    Server: PandoreServer
    Capture: PandoreCapture

    def __init__(self, ID: int, PacketSize: int, Direction: bool, DateTime: datetime, Protocol: str, Server: PandoreServer, Capture: PandoreCapture) -> None:
        self.ID = ID
        self.PacketSize = PacketSize
        self.Direction = Direction
        self.DateTime = DateTime
        self.Protocol = Protocol
        self.Server = Server
        self.Capture = Capture

class PandoreCaptureRequestNotDetailed():

    ID: int
    PascketSize: int
    Direction: bool
    DateTime: datetime
    Protocol: str
    ServerValue: str
    DNSValue: str
    Capture: int

    def __init__(self, ID: int, PacketSize: int, Direction: bool, DateTime: datetime, Protocol: str, ServerValue: str, DNSValue: str, Capture: int) -> None:
        self.ID = ID
        self.PacketSize = PacketSize
        self.Direction = Direction
        self.DateTime = DateTime
        self.Protocol = Protocol
        self.ServerValue = ServerValue
        self.DNSValue = DNSValue
        self.Capture = Capture

class PandoreAnalyticsServiceKeywords():
    Service: PandoreService
    Regex: str

    def __init__(self, Service: PandoreService, Regex: str) -> None:
        self.Service = Service
        self.Regex = Regex

class PandoreServiceStat():
    ServiceName: str
    UpTrafic : int
    DownTrafic: int

    def __init__(self, ServiceName: str, UpTrafic: int, DownTrafic: int) -> None:
        self.ServiceName = ServiceName
        self.UpTrafic = UpTrafic
        self.DownTrafic = DownTrafic