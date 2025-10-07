// ------------------------------------------------------------------
// General Project Configuration
// ------------------------------------------------------------------
environment = "prod"
aws_region  = "eu-west-3"

// The main domain for this environment (e.g., "prod.xelta.com")
domain_name = "prod.xelta.com"

// The root domain hosted zone ID where the subdomain will be delegated.
// Find this in the AWS Route 53 console for your root domain (e.g., "xelta.com").
// Example: "Z0123456789ABCDEFGHIJKL"
parent_zone_id = "YOUR_PARENT_ZONE_ID"

// ------------------------------------------------------------------
// Networking Configuration
// ------------------------------------------------------------------
vpc_cidr = "10.0.0.0/16"

// ------------------------------------------------------------------
// EKS Cluster Configuration
// ------------------------------------------------------------------
eks_cluster_version = "1.32"
eks_instance_types  = ["t3.large"] // Larger instances for prod
eks_min_nodes       = 1            // More nodes for HA
eks_max_nodes       = 2

// ------------------------------------------------------------------
// Database & Cache Configuration
// ------------------------------------------------------------------
// Set to `false` for prod to ensure a final snapshot is created.
db_skip_final_snapshot = false

// Aurora PostgreSQL config
aurora_instance_class = "db.r5.large" // Production-grade instance

// DocumentDB config
docdb_instance_class = "db.r5.large" // Production-grade instance

// ElastiCache Redis config
redis_node_type  = "cache.m5.large" // Production-grade node
redis_node_count = 2                // Enable multi-az failover
