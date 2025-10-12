# AWS CloudFormation Network Infrastructure

This project contains CloudFormation templates and scripts to deploy network infrastructure on AWS.

## Prerequisites

- AWS CLI installed and configured with valid credentials
- Appropriate IAM permissions to create VPC, subnets, internet gateways, NAT gateways, EC2 instances, RDS databases, and related resources
- EC2 Key Pair created in your AWS account (for bastion host access)
- Bash shell (Linux, macOS, or WSL on Windows)

## Project Structure

### Network Infrastructure
- `networking/network.yml` - CloudFormation template for VPC, subnets, and network resources
- `networking/network-parameters.json` - Parameter file for network configuration

### Servers and Security Groups
- `servers-and-security-groups/servers.yml` - CloudFormation template for EC2 instances, Auto Scaling Group, Load Balancer, and Bastion Host
- `servers-and-security-groups/servers-parameters.json` - Parameter file for server configuration

### Database
- `storage/db.yml` - CloudFormation template for RDS PostgreSQL database
- `storage/db-parameters.json` - Parameter file for database configuration

### Scripts
- `deploy.sh` - Script to deploy/update CloudFormation stacks
- `delete.sh` - Script to delete CloudFormation stacks

## Quick Start

1. **Create an EC2 Key Pair** (if you don't have one):
   ```bash
   aws ec2 create-key-pair --key-name bastion-access --query 'KeyMaterial' --output text > bastion-access.pem
   chmod 400 bastion-access.pem
   ```

2. **Get your public IP**:
   ```bash
   curl ifconfig.me
   ```

3. **Update parameter files** with your values:
   - Update `servers-and-security-groups/servers-parameters.json` with your key pair name and IP
   - Update `storage/db-parameters.json` with database credentials

4. **Deploy the stacks in order**:
   ```bash
   # 1. Network
   ./deploy.sh udacity-network networking/network.yml networking/network-parameters.json
   
   # 2. Servers
   ./deploy.sh udacity-servers servers-and-security-groups/servers.yml servers-and-security-groups/servers-parameters.json
   
   # 3. Database
   ./deploy.sh udacity-database storage/db.yml storage/db-parameters.json
   ```

5. **Access your infrastructure**:
   - Get bastion IP from CloudFormation outputs
   - SSH to bastion: `ssh -i bastion-access.pem ubuntu@<BASTION-IP>`
   - Port forward to database: `ssh -i bastion-access.pem -N -L 5432:<DB-ENDPOINT>:5432 ubuntu@<BASTION-IP>`

## Accessing Instances with Session Manager

The EC2 instances in this infrastructure are configured with AWS Systems Manager Session Manager, which provides secure access without SSH keys or open SSH ports.

### Prerequisites for Session Manager
- AWS CLI installed and configured
- Session Manager plugin installed: [Installation Guide](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html)

### Connect to Web Server Instances

**Find instance IDs:**
```bash
aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=udacity-project-ASG" \
    --query 'Reservations[*].Instances[*].[InstanceId,Tags[?Key==`Name`].Value|[0],State.Name]' \
    --output table
```

**Start a session:**
```bash
aws ssm start-session --target i-09b1e6f307304f808
```

**Connect to a specific instance (replace with actual instance ID):**
```bash
aws ssm start-session --target <INSTANCE-ID>
```

**Check SSM agent status on the instance:**
```bash
sudo systemctl status snap.amazon-ssm-agent.amazon-ssm-agent.service
```

### Session Manager Benefits
- ✅ No SSH keys required
- ✅ No open SSH ports (port 22) needed
- ✅ Full audit trail through CloudTrail
- ✅ Secure access through AWS IAM permissions
- ✅ Works with instances in private subnets

## Check Caller Identity

Make sure that the caller identity is the as expected.
```bash
aws sts get-caller-identity
```

## Deploying the Stacks

The infrastructure should be deployed in the following order due to dependencies:

### 1. Deploy Network Infrastructure

**Using the deploy script:**
```bash
./deploy.sh udacity-network networking/network.yml networking/network-parameters.json
```

**Using AWS CLI directly:**
```bash
aws cloudformation deploy \
    --stack-name udacity-network \
    --template-file networking/network.yml \
    --parameter-overrides file://networking/network-parameters.json \
    --region us-east-1
```

### 2. Deploy Servers and Bastion Host

**Important**: Update `servers-and-security-groups/servers-parameters.json` with your EC2 key pair name and public IP address before deploying.

**Using the deploy script:**
```bash
./deploy.sh udacity-servers servers-and-security-groups/servers.yml servers-and-security-groups/servers-parameters.json
```

**Using AWS CLI directly:**
```bash
aws cloudformation deploy \
    --stack-name udacity-servers \
    --template-file servers-and-security-groups/servers.yml \
    --parameter-overrides file://servers-and-security-groups/servers-parameters.json \
    --capabilities CAPABILITY_NAMED_IAM \
    --region us-east-1
```

### 3. Deploy Database (Optional)

**Important**: Update `storage/db-parameters.json` with your database credentials before deploying.

**Using the deploy script:**
```bash
./deploy.sh udacity-database storage/db.yml storage/db-parameters.json
```

**Using AWS CLI directly:**
```bash
aws cloudformation deploy \
    --stack-name udacity-database \
    --template-file storage/db.yml \
    --parameter-overrides file://storage/db-parameters.json \
    --region us-east-1
```

## Customizing Parameters

### Network Parameters

Edit `networking/network-parameters.json`:

```json
[
  {
    "ParameterKey": "EnvironmentName",
    "ParameterValue": "udacity-project"
  },
  {
    "ParameterKey": "VpcCIDR",
    "ParameterValue": "10.10.0.0/16"
  }
]
```

### Server Parameters

Edit `servers-and-security-groups/servers-parameters.json`:

```json
[
  {
    "ParameterKey": "EnvironmentName",
    "ParameterValue": "udacity-project"
  },
  {
    "ParameterKey": "KeyPairName",
    "ParameterValue": "your-keypair-name"
  },
  {
    "ParameterKey": "MyPublicIP",
    "ParameterValue": "your-ip-address/32"
  }
]
```

### Database Parameters

Edit `storage/db-parameters.json`:

```json
[
  {
    "ParameterKey": "EnvironmentName",
    "ParameterValue": "udacity-project"
  },
  {
    "ParameterKey": "RdsMasterUsername",
    "ParameterValue": "postgres"
  },
  {
    "ParameterKey": "RdsMasterPassword",
    "ParameterValue": "your-secure-password"
  }
]
```

## Monitoring Deployment

Check the status of your stack:

```bash
aws cloudformation describe-stacks --stack-name udacity-network
```

Watch stack events in real-time:

```bash
aws cloudformation describe-stack-events --stack-name udacity-network
```

## Deleting the Stack

### Using the delete script (recommended)

```bash
./delete.sh <stack-name>
```

**Example:**
```bash
./delete.sh udacity-network
```

The script will:
1. Prompt for confirmation (type `yes` to proceed)
2. Initiate stack deletion
3. Provide commands to monitor deletion progress

### Using AWS CLI directly

```bash
aws cloudformation delete-stack --stack-name udacity-network
```

**Monitor deletion:**
```bash
aws cloudformation describe-stacks --stack-name udacity-network
```

The stack will show `DELETE_IN_PROGRESS` status until fully deleted. Once complete, the stack will no longer appear in the list.

## Stack Outputs

After successful deployment, the stack exports several values that can be used by other stacks:

- VPC ID
- Public and private subnet IDs
- Route table IDs
- Availability zone information
- Bastion host public IP (from servers stack)
- Database endpoint (from database stack)

View stack outputs:

```bash
aws cloudformation describe-stacks --stack-name udacity-network --query 'Stacks[0].Outputs'
```

Get bastion host IP:
```bash
aws cloudformation describe-stacks --stack-name <servers-stack-name> \
  --query 'Stacks[0].Outputs[?OutputKey==`BastionHostPublicIP`].OutputValue' --output text
```

Get database endpoint:
```bash
aws cloudformation describe-stacks --stack-name <database-stack-name> \
  --query 'Stacks[0].Outputs[?OutputKey==`DBEndpoint`].OutputValue' --output text
```

## Accessing Infrastructure

### Bastion Host Access

The bastion host (jump server) provides secure access to private resources in your VPC.

#### Prerequisites

1. **EC2 Key Pair**: You must have an EC2 key pair created in your AWS account and the private key file (`.pem`) downloaded locally.

2. **Configure Parameters**: Update `servers-and-security-groups/servers-parameters.json`:
   ```json
   {
     "ParameterKey": "KeyPairName",
     "ParameterValue": "your-keypair-name"
   },
   {
     "ParameterKey": "MyPublicIP",
     "ParameterValue": "your-ip-address/32"
   }
   ```

3. **Find Your Public IP**:
   ```bash
   curl ifconfig.me
   # or
   curl ipinfo.io/ip
   ```

#### Setting Up SSH Key Permissions

Before connecting, ensure your private key has the correct permissions:

```bash
chmod 400 your-key.pem
```

Without this, SSH will reject the key with a "bad permissions" error.

#### Connecting to Bastion Host

**Method 1: Using SSH (Recommended)**
```bash
ssh -i your-key.pem ubuntu@<BASTION-PUBLIC-IP>
```

**Method 2: Using AWS EC2 Instance Connect**
1. Navigate to EC2 Console
2. Select your bastion instance
3. Click "Connect" → "EC2 Instance Connect"
4. Click "Connect"

**Note**: EC2 Instance Connect requires the security group to allow SSH from AWS's EC2 Instance Connect service IP ranges. This is pre-configured in the template for `us-east-1` region.

#### Accessing Private EC2 Instances via Bastion

Once connected to the bastion, you can SSH to private instances:

```bash
# From your local machine, SSH to bastion
ssh -i your-key.pem ubuntu@<BASTION-PUBLIC-IP>

# From bastion, SSH to private instances
ssh ubuntu@<PRIVATE-INSTANCE-IP>
```

**Option: SSH Agent Forwarding** (to avoid copying keys to bastion):
```bash
# Add key to SSH agent
ssh-add your-key.pem

# Connect with agent forwarding
ssh -A -i your-key.pem ubuntu@<BASTION-PUBLIC-IP>

# Now you can SSH to private instances without the key being on bastion
ssh ubuntu@<PRIVATE-INSTANCE-IP>
```

### Database Access via Port Forwarding

To connect to the RDS database in the private subnet from your local machine, use SSH port forwarding through the bastion host.

#### Prerequisites

1. Bastion host deployed and accessible (see above)
2. Database stack deployed with proper security groups

#### Setting Up Port Forward

**Forward local port to RDS database:**
```bash
ssh -i your-key.pem -N -L 5432:<DB-ENDPOINT>:5432 ubuntu@<BASTION-PUBLIC-IP>
```

**Parameters:**
- `-N`: Don't execute a remote command (just forward ports)
- `-L 5432:<DB-ENDPOINT>:5432`: Forward local port 5432 to database port 5432
- Replace `<DB-ENDPOINT>` with your RDS endpoint
- Replace `<BASTION-PUBLIC-IP>` with your bastion host IP

The terminal will appear to hang - this is normal. Keep this session open while using the database connection.

#### Connecting to Database

Once the port forward is active, connect to the database as if it were running locally:

**Using psql:**
```bash
psql -h localhost -p 5432 -U <username> -d exampledb
```

**Using connection string:**
```
postgresql://<username>:<password>@localhost:5432/exampledb
```

**Using GUI tools** (DBeaver, pgAdmin, etc.):
- Host: `localhost`
- Port: `5432`
- Database: `exampledb`
- Username: (your RDS master username)
- Password: (your RDS master password)

#### Port Forward in Background

To run the port forward in the background:

```bash
ssh -i your-key.pem -f -N -L 5432:<DB-ENDPOINT>:5432 ubuntu@<BASTION-PUBLIC-IP>
```

The `-f` flag runs SSH in the background. To close the connection later:

```bash
# Find the SSH process
ps aux | grep "ssh.*5432"

# Kill the process
kill <PID>
```

#### Security Notes

- The bastion security group only allows SSH from your specified IP address
- The database security group only allows connections from the bastion security group
- No direct internet access to the database - all connections must go through the bastion
- Port forwarding creates an encrypted tunnel through SSH

## Updating an Existing Stack

To update an existing stack with changes:

```bash
./update.sh <stack-name> <template-file> <parameter-file>
```

**Example:**
```bash
./update.sh udacity-network network.yml network-parameters.json
```

## Troubleshooting

### Stack creation failed

Check stack events for error details:
```bash
aws cloudformation describe-stack-events --stack-name <stack-name>
```

### Stack deletion stuck

Some resources may have dependencies. Check the CloudFormation console or stack events for specific resources that are blocking deletion.

### Permission errors

Ensure your AWS credentials have the necessary IAM permissions to create/delete VPC resources.

### SSH Key Permission Errors

If you see "bad permissions" error when connecting:
```bash
chmod 400 your-key.pem
```

The private key file must not be accessible by others.

### Cannot Connect to Bastion Host

1. **Verify security group allows your IP**:
   - Check that `MyPublicIP` parameter matches your current public IP
   - Your IP may change if using dynamic IP (re-check with `curl ifconfig.me`)

2. **Verify bastion is running**:
   ```bash
   aws ec2 describe-instances --filters "Name=tag:Name,Values=*BastionHost" --query 'Reservations[].Instances[].[InstanceId,State.Name,PublicIpAddress]'
   ```

3. **Check EC2 Instance Connect access** (if using browser-based connection):
   - Security group must allow SSH from EC2 Instance Connect service IP range
   - Template includes this for `us-east-1` region by default

### Cannot Connect to Database

1. **Verify port forward is active**:
   - Check that SSH port forward command is running
   - Look for the SSH process: `ps aux | grep "ssh.*5432"`

2. **Verify database security group**:
   - Must allow port 5432 from bastion security group
   - Check in AWS Console or CLI

3. **Get correct database endpoint**:
   ```bash
   aws cloudformation describe-stacks --stack-name udacity-database \
     --query 'Stacks[0].Outputs[?OutputKey==`DBEndpoint`].OutputValue' --output text
   ```

4. **Test connection from bastion**:
   ```bash
   # SSH to bastion first
   ssh -i your-key.pem ubuntu@<BASTION-IP>
   
   # Try to connect to database from bastion
   telnet <DB-ENDPOINT> 5432
   ```

### EC2 Instance Connect Failed

If browser-based connection fails:
1. Verify you're in the correct region (us-east-1)
2. If in a different region, update the security group with the correct EC2 Instance Connect IP range for that region
3. Alternatively, use SSH from terminal instead

## Region Configuration

By default, stacks are deployed to `us-east-1`. To change the region, modify the `--region` parameter in the scripts or CLI commands.

