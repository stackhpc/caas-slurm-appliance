"""
This module contains custom filters for the terraform_infra role.
"""


def terraform_infra_expand_groups_gen(primary_group, groups_map):
    """
    Returns a generator of groups for the given primary group and map of
    groups to child groups.
    """
    yield primary_group
    for group, child_groups in groups_map.items():
        if primary_group in child_groups:
            yield from terraform_infra_expand_groups_gen(group, groups_map)


def terraform_infra_expand_groups(primary_group, groups_map):
    """
    Returns the complete list of groups given a primary group and a map
    of groups to child groups.
    """
    # The return value must be a list, but we want only the unique elements
    return list(set(terraform_infra_expand_groups_gen(primary_group, groups_map)))


class FilterModule:
    """
    Custom filters for the terraform_infra role.
    """
    def filters(self):
        return {
            'terraform_infra_expand_groups': terraform_infra_expand_groups,
        }
