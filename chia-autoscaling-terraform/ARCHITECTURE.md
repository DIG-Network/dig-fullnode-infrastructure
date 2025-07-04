# Chia Blockchain Auto-scaling Infrastructure Architecture

## High-Level Architecture Diagram

```
                                   Internet
                                      │
                                      │
                              ┌───────┴────────┐
                              │ Network Load   │
                              │   Balancer     │
                              │  (Port 8444,   │
                              │   8555)        │
                              └───────┬────────┘
                                      │
                    ┌─────────────────┴─────────────────┐
                    │            VPC (10.0.0.0/16)      │
                    │                                   │
    ┌───────────────┴───────────────┐   ┌──────────────┴───────────────┐
    │     Public Subnets (3 AZs)    │   │    Private Subnets (3 AZs)   │
    │   10.0.1.0/24 - 10.0.3.0/24   │   │  10.0.11.0/24 - 10.0.13.0/24 │
    │                               │   │                              │
    │  ┌─────────┐  ┌─────────┐   │   │  ┌──────────────────────┐   │
    │  │   NAT   │  │   NAT   │   │   │  │   Auto Scaling Group  │   │
    │  │Gateway 1│  │Gateway 2│   │   │  │                      │   │
    │  └────┬────┘  └────┬────┘   │   │  │  ┌────────────────┐ │   │
    │       │            │         │   │  │  │  Chia Node 1   │ │   │
    └───────┼────────────┼─────────┘   │  │  │  (c5.xlarge)   │ │   │
            │            │             │  │  │  - 500GB EBS    │ │   │
            └────────────┴─────────────┼──│  │  - Chia Daemon  │ │   │
                                      │  │  └────────┬───────┘ │   │
                                      │  │           │         │   │
                                      │  │  ┌────────┴───────┐ │   │
                                      │  │  │  Chia Node 2   │ │   │
                                      │  │  │  (c5.xlarge)   │ │   │
                                      │  │  │  - 500GB EBS    │ │   │
                                      │  │  │  - Chia Daemon  │ │   │
                                      │  │  └────────┬───────┘ │   │
                                      │  │           │         │   │
                                      │  │  ┌────────┴───────┐ │   │
                                      │  │  │  Chia Node N   │ │   │
                                      │  │  │  (Scales 2-10)  │ │   │
                                      │  │  └────────┬───────┘ │   │
                                      │  └───────────┼─────────┘   │
                                      │              │             │
                                      └──────────────┼─────────────┘
                                                    │
                              ┌─────────────────────┴──────────────────┐
                              │                                        │
                    ┌─────────┴──────────┐              ┌─────────────┴──────────┐
                    │    EFS Mount       │              │      CloudWatch        │
                    │  (Shared Storage)  │              │   Logs & Metrics       │
                    │                    │              │                        │
                    │ /mnt/efs/          │              │ - Node logs            │
                    │  blockchain_data/  │              │ - CPU metrics          │
                    └────────────────────┘              │ - Scaling alarms       │
                                                       └────────────────────────┘
                              │
                              │ Periodic Sync
                              │
                    ┌─────────┴──────────┐
                    │    S3 Bucket       │
                    │ (Backup Storage)   │
                    │                    │
                    │ Blockchain         │
                    │  Snapshots         │
                    └────────────────────┘
```

## Component Details

### 1. Network Load Balancer (NLB)
- **Purpose**: Distributes incoming Chia network connections across healthy nodes
- **Ports**: 
  - 8444 (Chia fullnode)
  - 8555 (Chia RPC)
- **Health Checks**: TCP health checks on target nodes

### 2. VPC Network Architecture
- **CIDR**: 10.0.0.0/16
- **Availability Zones**: 3 (for high availability)
- **Subnets**:
  - Public: NAT Gateways and Load Balancer
  - Private: Chia nodes (protected from direct internet access)

### 3. Auto Scaling Group (ASG)
- **Scaling Triggers**:
  - Scale out: CPU > 70% for 5 minutes
  - Scale in: CPU < 30% for 10 minutes
- **Instance Configuration**:
  - Type: c5.xlarge (4 vCPU, 8 GB RAM)
  - Storage: 500GB gp3 SSD
  - OS: Ubuntu 22.04 LTS

### 4. Elastic File System (EFS)
- **Purpose**: Shared storage for blockchain data replication
- **Mount Point**: /mnt/efs
- **Performance**: General Purpose mode
- **Lifecycle**: Automatic transition to IA storage after 30 days

### 5. Data Flow

```
1. Initial Node Setup:
   EC2 Instance → Mount EFS → Copy blockchain data → Start Chia daemon

2. Client Connections:
   Internet → NLB → Target Group → Healthy Chia Node

3. Data Synchronization:
   Master Node → Local blockchain sync → Periodic copy to EFS → Available for new nodes

4. Backup Process:
   EFS Data → Scheduled snapshots → S3 Bucket (30-day retention)
```

## Security Architecture

### Network Security
```
┌─────────────────────────────────────────────────────┐
│                  Security Groups                     │
├─────────────────────────────────────────────────────┤
│ Load Balancer SG:                                   │
│   - Inbound: 8444, 8555 from 0.0.0.0/0             │
│   - Outbound: All traffic                          │
├─────────────────────────────────────────────────────┤
│ Chia Nodes SG:                                      │
│   - Inbound: 8444, 8555, 8447 from 0.0.0.0/0      │
│   - Inbound: 22 from VPC CIDR                     │
│   - Outbound: All traffic                          │
├─────────────────────────────────────────────────────┤
│ EFS SG:                                             │
│   - Inbound: 2049 from Chia Nodes SG              │
│   - Outbound: All traffic                          │
└─────────────────────────────────────────────────────┘
```

### IAM Roles and Permissions
```
EC2 Instance Role:
├── EFS Access Policy
│   └── elasticfilesystem:ClientMount, ClientWrite
├── S3 Access Policy
│   └── s3:GetObject, PutObject (blockchain snapshots bucket)
├── CloudWatch Logs Policy
│   └── logs:CreateLogStream, PutLogEvents
└── SSM Managed Instance Core
    └── For secure remote access
```

## Monitoring and Alerting

### CloudWatch Dashboard Widgets
1. **CPU Utilization**: Average and maximum across all nodes
2. **Network Load Balancer Health**: Healthy/unhealthy host count
3. **EFS Connections**: Active client connections
4. **Auto Scaling Activity**: Instance count and scaling events

### CloudWatch Alarms
- High CPU utilization (triggers scale-out)
- Low CPU utilization (triggers scale-in)
- Unhealthy target count > 0
- Healthy target count < 1

## Deployment Workflow

```
terraform init
      │
      ▼
terraform plan
      │
      ▼
terraform apply
      │
      ▼
┌─────┴──────┐
│  Phase 1   │ → Create VPC, Subnets, Security Groups
└─────┬──────┘
      │
      ▼
┌─────┴──────┐
│  Phase 2   │ → Create EFS, S3, IAM Roles
└─────┬──────┘
      │
      ▼
┌─────┴──────┐
│  Phase 3   │ → Create NLB, Target Groups
└─────┬──────┘
      │
      ▼
┌─────┴──────┐
│  Phase 4   │ → Create Launch Template, ASG
└─────┬──────┘
      │
      ▼
┌─────┴──────┐
│  Phase 5   │ → Instance initialization (user-data)
└────────────┘
```

## Cost Optimization Strategies

1. **Auto Scaling**: Automatically reduce instances during low demand
2. **EFS Lifecycle Management**: Move infrequent data to cheaper storage
3. **S3 Lifecycle Policies**: Delete old snapshots after retention period
4. **Instance Right-sizing**: Monitor metrics and adjust instance types
5. **Spot Instances**: Consider for non-critical environments

## Disaster Recovery

### Backup Strategy
- **EFS Backup**: AWS Backup integration enabled
- **S3 Snapshots**: Manual and automated blockchain backups
- **Multi-AZ**: Distributed across availability zones

### Recovery Process
1. New instances automatically mount EFS
2. Copy latest blockchain data from EFS
3. If EFS fails, restore from S3 snapshots
4. NLB automatically routes to healthy nodes