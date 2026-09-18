#!/usr/bin/env python3
"""Emit shell-quoted diagnostic variables from the trusted local lab inventory."""
import argparse
import json
import shlex
from pathlib import Path


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('inventory', type=Path)
    args = p.parse_args()
    inv = json.loads(args.inventory.read_text())
    values = {
        'AWS_REGION': inv['region'], 'BUCKET': inv['bucket'],
        'OBJECT_KEY': inv['object_key'], 'HOSTNAME_LAB': inv['hostname'],
        'ZONE_ID': inv['zone_id'], 'LOG_GROUP': inv['log_group'],
    }
    for node in ('client', 'server'):
        prefix = node.upper()
        i, n = inv['instances'][node], inv['networks'][node]
        values.update({f'{prefix}_ID': i['id'], f'{prefix}_SG': i['sg'],
                       f'{prefix}_RT': n['private_route_table_id'],
                       f'{prefix}_ACL': n['private_acl_id'],
                       f'{prefix}_S3_EP': n['s3_endpoint_id']})
    for key, value in values.items():
        print(f'export {key}={shlex.quote(str(value))}')


if __name__ == '__main__':
    main()
