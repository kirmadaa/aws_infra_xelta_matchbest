// ------------------------------------------------------------------
// General Project Configuration
// ------------------------------------------------------------------
environment = "dev"
aws_region  = "eu-central-1"

// The main domain for this environment (e.g., "dev.xelta.com")
domain_name = "xelta.ai"



// ------------------------------------------------------------------
// Networking Configuration
// ------------------------------------------------------------------
vpc_cidr = "10.1.0.0/16"

// ------------------------------------------------------------------
// EKS Cluster Configuration
// ------------------------------------------------------------------
eks_cluster_version = "1.32"
eks_instance_types  = ["t3.medium"]
eks_min_nodes       = 1
eks_max_nodes       = 2

// ------------------------------------------------------------------
// Database & Cache Configuration
// ------------------------------------------------------------------
// Set to `true` for dev/uat to allow deletion without snapshots.
db_skip_final_snapshot = true

// Aurora PostgreSQL config
aurora_instance_class = "db.t3.small"



// ElastiCache Redis config
redis_node_type  = "cache.t3.small"
redis_node_count = 1
