#!/usr/bin/env python3
"""
AWS Resource Cleanup Script for Terraform-managed Resources
Deletes resources tagged with 'ManagedBy=terraform' or 'managed_by=terraform'
Handles dependencies by deleting resources in the correct order.
"""

import boto3
import time
import sys
from botocore.exceptions import ClientError
from concurrent.futures import ThreadPoolExecutor, as_completed

# Configuration
REGIONS = ['us-east-1', 'eu-central-1', 'ap-south-1']
TAG_KEY = 'ManagedBy'
TAG_VALUES = ['terraform', 'Terraform']
DRY_RUN = False  # Set to False to actually delete resources

# Color codes for output
class Colors:
    HEADER = '\033[95m'
    OKBLUE = '\033[94m'
    OKCYAN = '\033[96m'
    OKGREEN = '\033[92m'
    WARNING = '\033[93m'
    FAIL = '\033[91m'
    ENDC = '\033[0m'
    BOLD = '\033[1m'

def log(message, color=None):
    """Print colored log message"""
    if color:
        print(f"{color}{message}{Colors.ENDC}")
    else:
        print(message)

def get_tagged_resources(session, region):
    """Get all resources with terraform tag"""
    client = session.client('resourcegroupstaggingapi', region_name=region)
    resources = []
    
    for tag_value in TAG_VALUES:
        try:
            paginator = client.get_paginator('get_resources')
            for page in paginator.paginate(
                TagFilters=[{'Key': TAG_KEY, 'Values': [tag_value]}]
            ):
                resources.extend(page['ResourceTagMappingList'])
        except ClientError as e:
            log(f"Error getting tagged resources in {region}: {e}", Colors.FAIL)
    
    return resources

def delete_eks_nodegroups(session, region, nodegroups):
    """Delete EKS node groups"""
    if not nodegroups:
        return
    
    eks = session.client('eks', region_name=region)
    
    for cluster_name, nodegroup_name in nodegroups:
        log(f"  Deleting EKS nodegroup: {nodegroup_name} from cluster {cluster_name}...", Colors.WARNING)
        if not DRY_RUN:
            try:
                eks.delete_nodegroup(clusterName=cluster_name, nodegroupName=nodegroup_name)
                log(f"  ✓ Initiated deletion of nodegroup: {nodegroup_name}", Colors.OKGREEN)
            except ClientError as e:
                log(f"  ✗ Error deleting nodegroup: {e}", Colors.FAIL)

def delete_eks_clusters(session, region, cluster_names):
    """Delete EKS clusters"""
    if not cluster_names:
        return
    
    eks = session.client('eks', region_name=region)
    
    for cluster_name in cluster_names:
        log(f"  Deleting EKS cluster: {cluster_name}...", Colors.WARNING)
        if not DRY_RUN:
            try:
                eks.delete_cluster(name=cluster_name)
                log(f"  ✓ Initiated deletion of cluster: {cluster_name}", Colors.OKGREEN)
            except ClientError as e:
                log(f"  ✗ Error deleting cluster: {e}", Colors.FAIL)

def delete_elasticache_clusters(session, region, cache_clusters):
    """Delete ElastiCache clusters"""
    if not cache_clusters:
        return
    
    elasticache = session.client('elasticache', region_name=region)
    
    for cluster_id in cache_clusters:
        log(f"  Deleting ElastiCache cluster: {cluster_id}...", Colors.WARNING)
        if not DRY_RUN:
            try:
                elasticache.delete_cache_cluster(
                    CacheClusterId=cluster_id,
                    FinalSnapshotIdentifier=None
                )
                log(f"  ✓ Deleted ElastiCache cluster: {cluster_id}", Colors.OKGREEN)
            except ClientError as e:
                log(f"  ✗ Error deleting ElastiCache cluster: {e}", Colors.FAIL)

def delete_elasticache_replication_groups(session, region, repl_groups):
    """Delete ElastiCache replication groups"""
    if not repl_groups:
        return
    
    elasticache = session.client('elasticache', region_name=region)
    
    for group_id in repl_groups:
        log(f"  Deleting ElastiCache replication group: {group_id}...", Colors.WARNING)
        if not DRY_RUN:
            try:
                elasticache.delete_replication_group(
                    ReplicationGroupId=group_id,
                    RetainPrimaryCluster=False
                )
                log(f"  ✓ Deleted replication group: {group_id}", Colors.OKGREEN)
            except ClientError as e:
                log(f"  ✗ Error deleting replication group: {e}", Colors.FAIL)

def delete_rds_clusters(session, region, cluster_ids):
    """Delete RDS clusters"""
    if not cluster_ids:
        return
    
    rds = session.client('rds', region_name=region)
    
    for cluster_id in cluster_ids:
        log(f"  Deleting RDS cluster: {cluster_id}...", Colors.WARNING)
        if not DRY_RUN:
            try:
                rds.delete_db_cluster(
                    DBClusterIdentifier=cluster_id,
                    SkipFinalSnapshot=True
                )
                log(f"  ✓ Deleted RDS cluster: {cluster_id}", Colors.OKGREEN)
            except ClientError as e:
                log(f"  ✗ Error deleting RDS cluster: {e}", Colors.FAIL)

def delete_load_balancers(session, region, lb_arns):
    """Delete load balancers"""
    if not lb_arns:
        return
    
    elbv2 = session.client('elbv2', region_name=region)
    
    for lb_arn in lb_arns:
        log(f"  Deleting load balancer: {lb_arn.split('/')[-1]}...", Colors.WARNING)
        if not DRY_RUN:
            try:
                elbv2.delete_load_balancer(LoadBalancerArn=lb_arn)
                log(f"  ✓ Deleted load balancer", Colors.OKGREEN)
            except ClientError as e:
                log(f"  ✗ Error deleting load balancer: {e}", Colors.FAIL)

def delete_target_groups(session, region, tg_arns):
    """Delete target groups"""
    if not tg_arns:
        return
    
    elbv2 = session.client('elbv2', region_name=region)
    
    for tg_arn in tg_arns:
        log(f"  Deleting target group: {tg_arn.split('/')[-1]}...", Colors.WARNING)
        if not DRY_RUN:
            try:
                elbv2.delete_target_group(TargetGroupArn=tg_arn)
                log(f"  ✓ Deleted target group", Colors.OKGREEN)
            except ClientError as e:
                log(f"  ✗ Error deleting target group: {e}", Colors.FAIL)

def delete_nat_gateways(session, region, nat_ids):
    """Delete NAT gateways"""
    if not nat_ids:
        return
    
    ec2 = session.client('ec2', region_name=region)
    
    for nat_id in nat_ids:
        log(f"  Deleting NAT gateway: {nat_id}...", Colors.WARNING)
        if not DRY_RUN:
            try:
                ec2.delete_nat_gateway(NatGatewayId=nat_id)
                log(f"  ✓ Deleted NAT gateway: {nat_id}", Colors.OKGREEN)
            except ClientError as e:
                log(f"  ✗ Error deleting NAT gateway: {e}", Colors.FAIL)
    
    if not DRY_RUN and nat_ids:
        log("  Waiting for NAT gateways to be deleted...", Colors.OKCYAN)
        time.sleep(60)

def delete_internet_gateways(session, region, igw_data):
    """Delete internet gateways"""
    if not igw_data:
        return
    
    ec2 = session.client('ec2', region_name=region)
    
    for igw_id, vpc_id in igw_data:
        log(f"  Deleting internet gateway: {igw_id}...", Colors.WARNING)
        if not DRY_RUN:
            try:
                ec2.detach_internet_gateway(InternetGatewayId=igw_id, VpcId=vpc_id)
                ec2.delete_internet_gateway(InternetGatewayId=igw_id)
                log(f"  ✓ Deleted internet gateway: {igw_id}", Colors.OKGREEN)
            except ClientError as e:
                log(f"  ✗ Error deleting internet gateway: {e}", Colors.FAIL)

def delete_subnets(session, region, subnet_ids):
    """Delete subnets"""
    if not subnet_ids:
        return
    
    ec2 = session.client('ec2', region_name=region)
    
    for subnet_id in subnet_ids:
        log(f"  Deleting subnet: {subnet_id}...", Colors.WARNING)
        if not DRY_RUN:
            try:
                ec2.delete_subnet(SubnetId=subnet_id)
                log(f"  ✓ Deleted subnet: {subnet_id}", Colors.OKGREEN)
            except ClientError as e:
                log(f"  ✗ Error deleting subnet: {e}", Colors.FAIL)

def delete_route_tables(session, region, rt_ids):
    """Delete route tables"""
    if not rt_ids:
        return
    
    ec2 = session.client('ec2', region_name=region)
    
    for rt_id in rt_ids:
        log(f"  Deleting route table: {rt_id}...", Colors.WARNING)
        if not DRY_RUN:
            try:
                ec2.delete_route_table(RouteTableId=rt_id)
                log(f"  ✓ Deleted route table: {rt_id}", Colors.OKGREEN)
            except ClientError as e:
                log(f"  ✗ Error deleting route table: {e}", Colors.FAIL)

def delete_security_groups(session, region, sg_ids):
    """Delete security groups"""
    if not sg_ids:
        return
    
    ec2 = session.client('ec2', region_name=region)
    
    for sg_id in sg_ids:
        log(f"  Deleting security group: {sg_id}...", Colors.WARNING)
        if not DRY_RUN:
            try:
                ec2.delete_security_group(GroupId=sg_id)
                log(f"  ✓ Deleted security group: {sg_id}", Colors.OKGREEN)
            except ClientError as e:
                log(f"  ✗ Error deleting security group: {e}", Colors.FAIL)

def delete_vpcs(session, region, vpc_ids):
    """Delete VPCs"""
    if not vpc_ids:
        return
    
    ec2 = session.client('ec2', region_name=region)
    
    for vpc_id in vpc_ids:
        log(f"  Deleting VPC: {vpc_id}...", Colors.WARNING)
        if not DRY_RUN:
            try:
                ec2.delete_vpc(VpcId=vpc_id)
                log(f"  ✓ Deleted VPC: {vpc_id}", Colors.OKGREEN)
            except ClientError as e:
                log(f"  ✗ Error deleting VPC: {e}", Colors.FAIL)

def delete_launch_templates(session, region, lt_ids):
    """Delete launch templates"""
    if not lt_ids:
        return
    
    ec2 = session.client('ec2', region_name=region)
    
    for lt_id in lt_ids:
        log(f"  Deleting launch template: {lt_id}...", Colors.WARNING)
        if not DRY_RUN:
            try:
                ec2.delete_launch_template(LaunchTemplateId=lt_id)
                log(f"  ✓ Deleted launch template: {lt_id}", Colors.OKGREEN)
            except ClientError as e:
                log(f"  ✗ Error deleting launch template: {e}", Colors.FAIL)

def delete_elasticache_snapshots(session, region, snapshot_names):
    """Delete ElastiCache snapshots"""
    if not snapshot_names:
        return
    
    elasticache = session.client('elasticache', region_name=region)
    
    for snapshot_name in snapshot_names:
        log(f"  Deleting ElastiCache snapshot: {snapshot_name}...", Colors.WARNING)
        if not DRY_RUN:
            try:
                elasticache.delete_snapshot(SnapshotName=snapshot_name)
                log(f"  ✓ Deleted snapshot: {snapshot_name}", Colors.OKGREEN)
            except ClientError as e:
                log(f"  ✗ Error deleting snapshot: {e}", Colors.FAIL)

def delete_elasticache_parameter_groups(session, region, param_groups):
    """Delete ElastiCache parameter groups"""
    if not param_groups:
        return
    
    elasticache = session.client('elasticache', region_name=region)
    
    for pg_name in param_groups:
        log(f"  Deleting ElastiCache parameter group: {pg_name}...", Colors.WARNING)
        if not DRY_RUN:
            try:
                elasticache.delete_cache_parameter_group(CacheParameterGroupName=pg_name)
                log(f"  ✓ Deleted parameter group: {pg_name}", Colors.OKGREEN)
            except ClientError as e:
                log(f"  ✗ Error deleting parameter group: {e}", Colors.FAIL)

def delete_elasticache_subnet_groups(session, region, subnet_groups):
    """Delete ElastiCache subnet groups"""
    if not subnet_groups:
        return
    
    elasticache = session.client('elasticache', region_name=region)
    
    for sg_name in subnet_groups:
        log(f"  Deleting ElastiCache subnet group: {sg_name}...", Colors.WARNING)
        if not DRY_RUN:
            try:
                elasticache.delete_cache_subnet_group(CacheSubnetGroupName=sg_name)
                log(f"  ✓ Deleted subnet group: {sg_name}", Colors.OKGREEN)
            except ClientError as e:
                log(f"  ✗ Error deleting subnet group: {e}", Colors.FAIL)

def delete_rds_parameter_groups(session, region, param_groups):
    """Delete RDS parameter groups"""
    if not param_groups:
        return
    
    rds = session.client('rds', region_name=region)
    
    for pg_name in param_groups:
        log(f"  Deleting RDS parameter group: {pg_name}...", Colors.WARNING)
        if not DRY_RUN:
            try:
                rds.delete_db_cluster_parameter_group(DBClusterParameterGroupName=pg_name)
                log(f"  ✓ Deleted parameter group: {pg_name}", Colors.OKGREEN)
            except ClientError as e:
                log(f"  ✗ Error deleting parameter group: {e}", Colors.FAIL)

def delete_rds_subnet_groups(session, region, subnet_groups):
    """Delete RDS subnet groups"""
    if not subnet_groups:
        return
    
    rds = session.client('rds', region_name=region)
    
    for sg_name in subnet_groups:
        log(f"  Deleting RDS subnet group: {sg_name}...", Colors.WARNING)
        if not DRY_RUN:
            try:
                rds.delete_db_subnet_group(DBSubnetGroupName=sg_name)
                log(f"  ✓ Deleted subnet group: {sg_name}", Colors.OKGREEN)
            except ClientError as e:
                log(f"  ✗ Error deleting subnet group: {e}", Colors.FAIL)

def get_igw_vpc_mapping(session, region, igw_ids):
    """Get VPC attachments for internet gateways"""
    if not igw_ids:
        return []
    
    ec2 = session.client('ec2', region_name=region)
    igw_data = []
    
    try:
        response = ec2.describe_internet_gateways(InternetGatewayIds=igw_ids)
        for igw in response['InternetGateways']:
            if igw['Attachments']:
                vpc_id = igw['Attachments'][0]['VpcId']
                igw_data.append((igw['InternetGatewayId'], vpc_id))
    except ClientError as e:
        log(f"  Error getting IGW attachments: {e}", Colors.FAIL)
    
    return igw_data

def process_region(region):
    """Process all resources in a region"""
    log(f"\n{'='*60}", Colors.HEADER)
    log(f"Processing region: {region}", Colors.HEADER)
    log(f"{'='*60}", Colors.HEADER)
    
    session = boto3.Session(region_name=region)
    
    log("\nScanning for Terraform-managed resources...", Colors.OKCYAN)
    resources = get_tagged_resources(session, region)
    
    if not resources:
        log(f"No Terraform-managed resources found in {region}", Colors.OKGREEN)
        return
    
    log(f"Found {len(resources)} resources", Colors.OKBLUE)
    
    # Categorize resources
    eks_clusters = []
    eks_nodegroups = []
    elasticache_clusters = []
    elasticache_repl_groups = []
    elasticache_snapshots = []
    elasticache_param_groups = []
    elasticache_subnet_groups = []
    rds_clusters = []
    rds_param_groups = []
    rds_subnet_groups = []
    load_balancers = []
    target_groups = []
    nat_gateways = []
    internet_gateways = []
    subnets = []
    route_tables = []
    security_groups = []
    vpcs = []
    launch_templates = []
    
    for resource in resources:
        arn = resource['ResourceARN']
        
        if ':eks:' in arn and ':cluster/' in arn:
            cluster_name = arn.split('cluster/')[-1]
            eks_clusters.append(cluster_name)
        elif ':eks:' in arn and ':nodegroup/' in arn:
            parts = arn.split('nodegroup/')[-1].split('/')
            cluster_name = parts[0]
            nodegroup_name = parts[1]
            eks_nodegroups.append((cluster_name, nodegroup_name))
        elif ':elasticache:' in arn and ':cluster:' in arn:
            cluster_id = arn.split(':')[-1]
            elasticache_clusters.append(cluster_id)
        elif ':elasticache:' in arn and ':replicationgroup:' in arn:
            group_id = arn.split(':')[-1]
            elasticache_repl_groups.append(group_id)
        elif ':elasticache:' in arn and ':snapshot:' in arn:
            snapshot_name = arn.split(':')[-1]
            elasticache_snapshots.append(snapshot_name)
        elif ':elasticache:' in arn and ':parametergroup:' in arn:
            pg_name = arn.split(':')[-1]
            elasticache_param_groups.append(pg_name)
        elif ':elasticache:' in arn and ':subnetgroup:' in arn:
            sg_name = arn.split(':')[-1]
            elasticache_subnet_groups.append(sg_name)
        elif ':rds:' in arn and ':cluster:' in arn:
            cluster_id = arn.split(':')[-1]
            rds_clusters.append(cluster_id)
        elif ':rds:' in arn and ':cluster-pg:' in arn:
            pg_name = arn.split(':')[-1]
            rds_param_groups.append(pg_name)
        elif ':rds:' in arn and ':subgrp:' in arn:
            sg_name = arn.split(':')[-1]
            rds_subnet_groups.append(sg_name)
        elif ':elasticloadbalancing:' in arn and 'loadbalancer/' in arn:
            load_balancers.append(arn)
        elif ':elasticloadbalancing:' in arn and 'targetgroup/' in arn:
            target_groups.append(arn)
        elif ':ec2:' in arn and 'natgateway/' in arn:
            nat_gateways.append(arn.split('/')[-1])
        elif ':ec2:' in arn and 'internet-gateway/' in arn:
            internet_gateways.append(arn.split('/')[-1])
        elif ':ec2:' in arn and 'subnet/' in arn:
            subnets.append(arn.split('/')[-1])
        elif ':ec2:' in arn and 'route-table/' in arn:
            route_tables.append(arn.split('/')[-1])
        elif ':ec2:' in arn and 'security-group/' in arn:
            sg_id = arn.split('/')[-1]
            if sg_id != 'default':
                security_groups.append(sg_id)
        elif ':ec2:' in arn and 'vpc/' in arn:
            vpcs.append(arn.split('/')[-1])
        elif ':ec2:' in arn and 'launch-template/' in arn:
            launch_templates.append(arn.split('/')[-1])
    
    # Show categorization
    log(f"\nCategorized resources:", Colors.OKCYAN)
    categories = [
        ("EKS Clusters", eks_clusters),
        ("EKS Node Groups", eks_nodegroups),
        ("ElastiCache Clusters", elasticache_clusters),
        ("ElastiCache Replication Groups", elasticache_repl_groups),
        ("ElastiCache Snapshots", elasticache_snapshots),
        ("ElastiCache Parameter Groups", elasticache_param_groups),
        ("ElastiCache Subnet Groups", elasticache_subnet_groups),
        ("RDS Clusters", rds_clusters),
        ("RDS Parameter Groups", rds_param_groups),
        ("RDS Subnet Groups", rds_subnet_groups),
        ("Load Balancers", load_balancers),
        ("Target Groups", target_groups),
        ("NAT Gateways", nat_gateways),
        ("Internet Gateways", internet_gateways),
        ("Subnets", subnets),
        ("Route Tables", route_tables),
        ("Security Groups", security_groups),
        ("VPCs", vpcs),
        ("Launch Templates", launch_templates)
    ]
    
    for name, items in categories:
        if items:
            log(f"  {name}: {len(items)}", Colors.OKBLUE)
    
    # Get IGW-VPC mappings
    igw_data = get_igw_vpc_mapping(session, region, internet_gateways)
    
    # Delete in dependency order
    log("\n--- Phase 1: EKS Resources ---", Colors.BOLD)
    delete_eks_nodegroups(session, region, eks_nodegroups)
    if eks_nodegroups and not DRY_RUN:
        log("  Waiting for node groups to be deleted...", Colors.OKCYAN)
        time.sleep(120)
    delete_eks_clusters(session, region, eks_clusters)
    if eks_clusters and not DRY_RUN:
        log("  Waiting for EKS clusters to be deleted...", Colors.OKCYAN)
        time.sleep(120)
    
    log("\n--- Phase 2: Database & Cache Resources ---", Colors.BOLD)
    delete_elasticache_replication_groups(session, region, elasticache_repl_groups)
    delete_elasticache_clusters(session, region, elasticache_clusters)
    delete_rds_clusters(session, region, rds_clusters)
    if (elasticache_clusters or elasticache_repl_groups or rds_clusters) and not DRY_RUN:
        log("  Waiting for databases to be deleted...", Colors.OKCYAN)
        time.sleep(60)
    
    log("\n--- Phase 3: Load Balancing ---", Colors.BOLD)
    delete_load_balancers(session, region, load_balancers)
    if load_balancers and not DRY_RUN:
        time.sleep(30)
    delete_target_groups(session, region, target_groups)
    
    log("\n--- Phase 4: Network Infrastructure ---", Colors.BOLD)
    delete_nat_gateways(session, region, nat_gateways)
    delete_internet_gateways(session, region, igw_data)
    
    log("\n--- Phase 5: Subnets and Routing ---", Colors.BOLD)
    delete_subnets(session, region, subnets)
    delete_route_tables(session, region, route_tables)
    
    log("\n--- Phase 6: Security and VPC ---", Colors.BOLD)
    delete_security_groups(session, region, security_groups)
    delete_vpcs(session, region, vpcs)
    
    log("\n--- Phase 7: Supporting Resources ---", Colors.BOLD)
    delete_launch_templates(session, region, launch_templates)
    delete_elasticache_snapshots(session, region, elasticache_snapshots)
    delete_elasticache_subnet_groups(session, region, elasticache_subnet_groups)
    delete_elasticache_parameter_groups(session, region, elasticache_param_groups)
    delete_rds_subnet_groups(session, region, rds_subnet_groups)
    delete_rds_parameter_groups(session, region, rds_param_groups)
    
    log(f"\n✓ Completed processing {region}", Colors.OKGREEN)

def main():
    """Main execution function"""
    log(f"\n{'='*60}", Colors.HEADER)
    log("AWS Terraform Resource Cleanup Script", Colors.HEADER)
    log(f"{'='*60}", Colors.HEADER)
    
    if DRY_RUN:
        log("\n⚠️  DRY RUN MODE - No resources will be deleted", Colors.WARNING)
        log("Set DRY_RUN = False to actually delete resources\n", Colors.WARNING)
    else:
        log("\n⚠️  LIVE MODE - Resources WILL be deleted!", Colors.FAIL)
        response = input("Are you sure you want to continue? (type 'DELETE' to confirm): ")
        if response != 'DELETE':
            log("Aborted.", Colors.OKGREEN)
            sys.exit(0)
    
    log(f"\nTarget regions: {', '.join(REGIONS)}", Colors.OKBLUE)
    log(f"Looking for tag: {TAG_KEY} = {' or '.join(TAG_VALUES)}\n", Colors.OKBLUE)
    
    for region in REGIONS:
        try:
            process_region(region)
        except Exception as e:
            log(f"\n✗ Error processing region {region}: {e}", Colors.FAIL)
            import traceback
            traceback.print_exc()
            continue
    
    log(f"\n{'='*60}", Colors.HEADER)
    log("Cleanup Complete!", Colors.HEADER)
    log(f"{'='*60}", Colors.HEADER)

if __name__ == "__main__":
    main()