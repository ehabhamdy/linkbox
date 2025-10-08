# AWS CloudFormation Network Infrastructure

This project contains CloudFormation templates and scripts to deploy network infrastructure on AWS.

## Prerequisites

- AWS CLI installed and configured with valid credentials
- Appropriate IAM permissions to create VPC, subnets, internet gateways, NAT gateways, and related resources
- Bash shell (Linux, macOS, or WSL on Windows)

## Files

- `network.yml` - CloudFormation template for network infrastructure
- `network-parameters.json` - Parameter file for customizing the deployment
- `deploy.sh` - Script to deploy/update the CloudFormation stack
- `delete.sh` - Script to delete the CloudFormation stack
- `update.sh` - Script to update an existing stack

## Check caller identity

Make sure that the caller identity is the as expected.
```bash
aws sts get-caller-identity
```

## Deploying the Stack

### Using the deploy script (recommended)

```bash
./deploy.sh <stack-name> <template-file> <parameter-file>
```

**Example:**
```bash
./deploy.sh udacity-network network.yml network-parameters.json
```

### Using AWS CLI directly

```bash
aws cloudformation deploy \
    --stack-name udacity-network \
    --template-file network.yml \
    --parameter-overrides file://network-parameters.json \
    --region us-east-1
```

## Customizing Parameters

Edit `network-parameters.json` to customize the deployment:

```json
[
  {
    "ParameterKey": "EnvironmentName",
    "ParameterValue": "YourEnvironmentName"
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

View stack outputs:

```bash
aws cloudformation describe-stacks --stack-name udacity-network --query 'Stacks[0].Outputs'
```

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
aws cloudformation describe-stack-events --stack-name udacity-network
```

### Stack deletion stuck

Some resources may have dependencies. Check the CloudFormation console or stack events for specific resources that are blocking deletion.

### Permission errors

Ensure your AWS credentials have the necessary IAM permissions to create/delete VPC resources.

## Region Configuration

By default, stacks are deployed to `us-east-1`. To change the region, modify the `--region` parameter in the scripts or CLI commands.

