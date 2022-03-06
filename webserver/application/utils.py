def second_to_duration(duration_second: int) -> str:
    minutes = 0
    hours = 0

    while(duration_second >= 3600):
        duration_second -= 3600
        hours += 1

    while(duration_second >= 60):
        duration_second -= 60
        minutes += 1
    
    if(hours < 10):
        hours = "0" + str(hours)
    else:
        hours = str(hours)

    if(minutes < 10):
        minutes = "0" + str(minutes)
    else:
        minutes = str(minutes)

    if(int(duration_second) < 10):
        duration_second = "0" + str(int(duration_second))
    else:
        duration_second = str(int(duration_second))

    return hours + ":" + minutes + ":" + str(duration_second)

def octet_to_string(octet: int, decimals: int) -> str:
    unit = "B"

    if(octet < 1024):
        octet = str(round(octet, decimals))
        unit = "B"
    elif(octet < (1024*1024)):
        octet = str(round(octet/1024, decimals))
        unit = "kB"
    else:
        octet = str(round(octet/(1024*1024), decimals))
        unit = "MB"

    return octet + " " + unit