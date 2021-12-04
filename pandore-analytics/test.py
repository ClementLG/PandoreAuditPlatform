from pandore_analytics import PandoreAnalytics

analytics = PandoreAnalytics()

analytics.analyse_ip_dns('8.8.8.8', "google.com")
analytics.analyse_ip_dns('8.8.8.8')