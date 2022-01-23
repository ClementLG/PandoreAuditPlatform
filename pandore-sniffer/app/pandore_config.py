# PANDORE AGENT CONFIG

# IMPORTS======================================================================

import configparser


# CLASS=========================================================================

class PandoreConfig:
    def __init__(self, file_name):
        self.file_name = file_name
        self.config = configparser.ConfigParser()
        self.config.read(file_name)

    def get_json_config(self):
        json_output = {}
        for sect in self.config.sections():
            json_output[sect] = dict(self.config.items(sect))
        return json_output

    def get_parameter(self, section, parameter):
        if self.config.has_option(section, parameter):
            return self.config[section][parameter]
        else:
            print("Error getting parameter : " + section + " with " + parameter + " doesn't exist")

    def update_parameter(self, section, parameter, value):
        if self.config.has_option(section, parameter):
            self.config[section][parameter] = str(value)
        else:
            print("Error updating parameter : "+section+" with "+parameter+" doesn't exist")
