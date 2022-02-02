from application.models import PandoreAnalyticsServiceKeywords
import threading

class PandoreAnalyticsRunningConfiguration():
    __numberOfUnknownServers: int
    __numberOfProcessedServers: int
    __dictionary: PandoreAnalyticsServiceKeywords
    __stopAnalytics: bool

    def __init__(self, numberOfUnknownServers: int, dictionary: list[PandoreAnalyticsServiceKeywords]):
        self.lock = threading.Lock()
        self.__dictionary = dictionary
        self.__numberOfProcessedServers = 0
        self.__numberOfUnknownServers = numberOfUnknownServers
        self.__stopAnalytics = False

    def getNumberOfUnknownServers(self) -> int:
        return self.__numberOfUnknownServers

    def getNumberOfProcessedServers(self) -> int:
        numberOfProccessedServers = 0
        self.lock.acquire()
        numberOfProccessedServers = self.__numberOfProcessedServers
        self.lock.release()
        return numberOfProccessedServers

    def getDicitonary(self):
        dic = None
        self.lock.acquire()
        dic = self.__dictionary
        self.lock.release()
        return dic

    def incrementNumberOfProcessedServers(self):
        self.lock.acquire()
        self.__numberOfProcessedServers = self.__numberOfProcessedServers + 1
        self.lock.release()

    def setStopAnalytics(self):
        self.lock.acquire()
        self.__stopAnalytics = True
        self.lock.release()

    def getStopAnalytics(self) -> bool:
        stopAnalytics = False
        self.lock.acquire()
        stopAnalytics = self.__stopAnalytics
        self.lock.release()
        return stopAnalytics