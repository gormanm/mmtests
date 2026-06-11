#!/usr/bin/env python3
"""
Parse and flatten kernel CPU range strings into individual CPU numbers.

The command-line argument is expected to use kernel-style CPU range string
(e.g., "0-3,5,7-9") and outputs each CPU number on a separate line.

"""
import sys
import argparse

def parse_kernel_range_list(cpu_ranges):
    """
    Parse kernel CPU range notation and return individual CPU ids.
    Note that ordering is numeric and adjacent CPU ids are not
    necessarily related by topology (e.g. SMT, shared LLC, node)
    etc.

    Args:
        range_list: String in kernel CPU format (e.g., "0-3,5,8-12")

    Returns:
        Sorted list of CPU numbers
    """
    cpus = []

    range_list = cpu_ranges.strip()
    for cpu_range in range_list.split(','):
        from_to = cpu_range.split('-')
        from_cpu = int(from_to[0])
        to_cpu = int(from_to[1]) if len(from_to) > 1 else from_cpu

        for i in range(from_cpu, to_cpu + 1):
            cpus.append(i)

    return sorted(set(cpus))

def main():
    cpulist = None

    parser = argparse.ArgumentParser(description='Parse kernel CPU range notation and return individual CPU ids.')
    parser.add_argument('cpulist', help='cpulist in kernel cpulist-format (e.g. 0-3,5,8-12)')
    args = parser.parse_args()

    for cpu in parse_kernel_range_list(args.cpulist):
        print(cpu)

if __name__ == '__main__':
    main()
