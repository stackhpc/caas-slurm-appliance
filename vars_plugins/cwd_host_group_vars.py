DOCUMENTATION = '''
    name: cwd_host_group_vars
    version_added: "2.4"
    short_description: Loads group_vars and host_vars from the current working directory.
    requirements:
        - whitelist in configuration
    description:
        - Loads YAML vars into corresponding groups/hosts in group_vars/ and host_vars/ directories.
        - Files are restricted by extension to one of .yaml, .json, .yml or no extension.
        - Hidden (starting with '.') and backup (ending with '~') files and directories are ignored.
'''

import os
from ansible.plugins.vars.host_group_vars import VarsModule as HostGroupVarsModule


class VarsModule(HostGroupVarsModule):
    """
    Custom vars plugin that always reads host and group vars from the current working directory.
    """
    def get_vars(self, loader, path, entities, cache = True):
        return super().get_vars(loader, os.getcwd(), entities, cache)
