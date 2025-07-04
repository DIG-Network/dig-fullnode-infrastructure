# Chia Blockchain Auto-scaling Infrastructure

This Terraform project creates a fully automated, scalable infrastructure for running Chia blockchain nodes on AWS.

## Architecture Overview

The infrastructure consists of:

- **Auto Scaling Group**: Automatically scales Chia nodes based on CPU utilization
- **Network Load Balancer**: Distributes traffic across multiple Chia nodes
- **EFS (Elastic File System)**: Shared storage for blockchain data replication
- **S3**: Backup storage for blockchain snapshots
- **VPC**: Isolated network with public/private subnets across multiple AZs
- **CloudWatch**: Monitoring, logging, and alerting

## Key Features

1. **Automatic Scaling**: Scales out when CPU > 70%, scales in when CPU < 30%
2. **Data Replication**: New nodes automatically copy blockchain data from EFS
3. **High Availability**: Distributed across multiple availability zones
4. **Load Balancing**: Network Load Balancer for Chia ports (8444, 8555)
5. **Monitoring**: CloudWatch dashboard and alarms for system health
6. **Security**: Private subnets, security groups, and encrypted storage

## Prerequisites

- AWS Account with appropriate permissions
- Terraform >= 1.0
- AWS CLI configured with credentials
- An existing EC2 key pair for SSH access

## Quick Start

1. **Clone this repository**
   ```bash
   git clone <repository-url>
   cd chia-autoscaling-terraform
   ```

2. **Copy and configure terraform.tfvars**
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars with your configuration
   ```

3. **Initialize Terraform**
   ```bash
   terraform init
   ```

4. **Review the plan**
   ```bash
   terraform plan
   ```

5. **Deploy the infrastructure**
   ```bash
   terraform apply
   ```

## Module Structure

```
chia-autoscaling-terraform/
├── main.tf                 # Main configuration
├── variables.tf            # Input variables
├── outputs.tf              # Output values
├── terraform.tfvars.example # Example configuration
├── modules/
│   ├── networking/         # VPC, subnets, security groups
│   ├── storage/            # EFS, S3, IAM roles
│   ├── compute/            # EC2 launch template, ASG
│   └── load-balancer/      # Network Load Balancer
└── scripts/
    └── user-data.sh        # EC2 initialization script
```

## Configuration Variables

### Required Variables

- `key_pair_name`: AWS EC2 key pair name for SSH access

### Important Variables

- `instance_type`: EC2 instance type (default: c5.xlarge)
- `asg_min_size`: Minimum number of nodes (default: 2)
- `asg_max_size`: Maximum number of nodes (default: 10)
- `asg_desired_capacity`: Initial number of nodes (default: 3)

See `variables.tf` for all available configuration options.

## Data Replication Strategy

1. **Master Node**: The first node syncs the blockchain from the network
2. **EFS Storage**: Blockchain data is periodically synced to EFS
3. **New Nodes**: Copy blockchain data from EFS to local storage before starting
4. **Performance**: Local SSD storage ensures optimal node performance

## Monitoring and Alerts

The infrastructure includes:

- **CloudWatch Dashboard**: Real-time metrics visualization
- **Auto Scaling Alarms**: CPU-based scaling triggers
- **Health Check Monitoring**: Load balancer health status
- **Log Collection**: Chia node logs sent to CloudWatch Logs

Access the dashboard URL from the Terraform outputs.

## Connecting to Chia Nodes

After deployment, use the load balancer endpoints:

```bash
# Get connection endpoints
terraform output chia_fullnode_endpoint
terraform output chia_rpc_endpoint

# Connect to Chia fullnode
chia show -a $(terraform output -raw load_balancer_dns_name):8444

# Use RPC endpoint
curl http://$(terraform output -raw load_balancer_dns_name):8555/get_blockchain_state
```

## Testing the Infrastructure

1. **Deploy with minimum instances**
   ```bash
   terraform apply -var="asg_min_size=1" -var="asg_desired_capacity=1"
   ```

2. **Verify EFS mounting**
   - SSH into an instance
   - Check `/mnt/efs` is mounted
   - Verify blockchain data directory

3. **Test auto scaling**
   - Generate load on instances
   - Monitor CloudWatch dashboard
   - Verify new instances launch

4. **Test load balancer**
   - Connect to Chia via load balancer endpoint
   - Verify connections are distributed

## Maintenance

### Updating Blockchain Data on EFS

To designate a master node for EFS syncing:
```bash
# SSH into the chosen instance
sudo touch /etc/chia-master-node
```

### Backing Up to S3

Manual backup command (run on any node):
```bash
aws s3 sync /home/ubuntu/.chia/mainnet/db/ s3://[bucket-name]/manual-backup/
```

### Scaling Manually

```bash
# Scale up
aws autoscaling set-desired-capacity \
  --auto-scaling-group-name $(terraform output -raw autoscaling_group_name) \
  --desired-capacity 5

# Scale down
aws autoscaling set-desired-capacity \
  --auto-scaling-group-name $(terraform output -raw autoscaling_group_name) \
  --desired-capacity 2
```

## Cost Optimization

1. **Use Spot Instances** (for non-critical environments)
   - Modify launch template to use spot instances
   - Set appropriate spot price

2. **Scheduled Scaling**
   - Add scheduled actions for predictable load patterns
   - Scale down during off-peak hours

3. **EFS Lifecycle Policies**
   - Already configured to move infrequent data to IA storage class

## Troubleshooting

### Common Issues

1. **Nodes not syncing**
   - Check EFS mount: `df -h | grep efs`
   - Verify blockchain data exists on EFS
   - Check CloudWatch logs

2. **Auto scaling not working**
   - Verify CloudWatch alarms are in OK state
   - Check scaling policies in ASG
   - Review instance health checks

3. **Load balancer unhealthy targets**
   - Check security group rules
   - Verify Chia service is running
   - Review target group health check settings

### Logs Location

- **User Data Log**: `/var/log/user-data.log`
- **Chia Debug Log**: `/home/ubuntu/.chia/mainnet/log/debug.log`
- **EFS Sync Log**: `/var/log/chia-efs-sync.log`
- **CloudWatch Logs**: Check log group in AWS Console

## Security Considerations

1. **Network Security**
   - Chia nodes in private subnets
   - Only load balancer exposed publicly
   - Security groups restrict traffic

2. **Data Security**
   - EFS encrypted at rest
   - S3 bucket encrypted
   - EBS volumes encrypted

3. **Access Control**
   - IAM roles with least privilege
   - Instance profile for AWS service access
   - SSH access only via bastion (recommended)

## Cleanup

To destroy all resources:
```bash
terraform destroy
```

**Warning**: This will delete all resources including EFS data and S3 backups.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

## License

[Your License Here]

## Support

For issues and questions:
- Open an issue in the repository
- Check CloudWatch logs for debugging
- Review Terraform state for resource status