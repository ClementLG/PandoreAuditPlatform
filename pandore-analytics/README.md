# Analytics Agent

## A - description

Pandore Analytics performs processing on the captured data in order to automate the analysis.
 - Association of IP / DNS to a service
 - Characterization of traffic by category (Ads, telemetry ...)

## B - Basic usage

This application is used by the GUI of the Pandore project.

*Example*:
```
from pandore_analytics import PandoreAnalytics
analytics = PandoreAnalytics()
analytics.analyse_ip_dns('8.8.8.8')
analytics.analyse_ip_dns('8.8.8.8',"google.com")
````

