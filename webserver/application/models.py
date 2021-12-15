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

    def __init__(self, ID: int, Name: str, StartTime: datetime, EndTime: datetime, Description: str, Interface: str, ConnectionType: str) -> None:
        self.ID = ID
        self.Name = Name
        self.StartTime = StartTime
        self.EndTime = EndTime
        self.Description = Description
        self.Interface = Interface
        self.ConnectionType = ConnectionType

class PandoreService():

    ID: int
    Name: str

    def __init__(self, ID: int, Name: str) -> None:
        self.ID = ID
        self.Name = Name

class PandoreDNS():

    ID: int
    Value: str

    def __init__(self, ID: int, Value: str) -> None:
        self.ID = ID
        self.Value = Value

class PandoreServer():

    ID: int
    Address: str
    DNS: PandoreDNS
    Service: PandoreService

    def __init__(self, ID: int, Address: str, DNS: PandoreDNS, Service: PandoreService) -> None:
        self.ID = ID
        self.Address = Address
        self.DNS = DNS
        self.Service = Service

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