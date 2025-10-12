#!/bin/bash

if [ $# -lt 3 ] || [ $# -gt 4 ]; then
    echo "Usage: $0 <stack-name> <template-file> <parameter-file> [changeset-name]"
    exit 1
fi

STACK_NAME="$1"
TEMPLATE_FILE="$2"
PARAMETER_FILE="$3"
CHANGESET_NAME="${4:-changeset-$(date +%Y%m%d-%H%M%S)}"

echo "Creating CloudFormation changeset for stack: $STACK_NAME"
echo "Using template: $TEMPLATE_FILE"
echo "Using parameter file: $PARAMETER_FILE"
echo "Changeset name: $CHANGESET_NAME"
echo ""

# Check if template file exists
if [ ! -f "$TEMPLATE_FILE" ]; then
    echo "Error: Template file '$TEMPLATE_FILE' not found!"
    exit 1
fi

# Check if parameter file exists
if [ ! -f "$PARAMETER_FILE" ]; then
    echo "Error: Parameter file '$PARAMETER_FILE' not found!"
    exit 1
fi

# Create the changeset
echo "Creating changeset..."
aws cloudformation create-change-set \
    --stack-name "$STACK_NAME" \
    --change-set-name "$CHANGESET_NAME" \
    --template-body file://"$TEMPLATE_FILE" \
    --parameters file://"$PARAMETER_FILE" \
    --capabilities CAPABILITY_NAMED_IAM \
    --region us-east-1

if [ $? -ne 0 ]; then
    echo "Failed to create changeset. Please check the error message above."
    exit 1
fi

echo ""
echo "Changeset creation initiated. Waiting for it to be ready..."

# Wait for changeset to be created
aws cloudformation wait change-set-create-complete \
    --stack-name "$STACK_NAME" \
    --change-set-name "$CHANGESET_NAME" \
    --region us-east-1

if [ $? -ne 0 ]; then
    echo ""
    echo "Warning: Changeset creation may have failed or timed out."
    echo "Checking changeset status..."
    
    # Get the changeset status
    STATUS=$(aws cloudformation describe-change-set \
        --stack-name "$STACK_NAME" \
        --change-set-name "$CHANGESET_NAME" \
        --region us-east-1 \
        --query 'Status' \
        --output text 2>/dev/null)
    
    if [ "$STATUS" == "FAILED" ]; then
        echo ""
        echo "Changeset creation FAILED. Reason:"
        aws cloudformation describe-change-set \
            --stack-name "$STACK_NAME" \
            --change-set-name "$CHANGESET_NAME" \
            --region us-east-1 \
            --query 'StatusReason' \
            --output text
        exit 1
    fi
fi

echo ""
echo "Changeset created successfully!"
echo ""
echo "=========================================="
echo "CHANGESET DETAILS"
echo "=========================================="

# Display the changeset
aws cloudformation describe-change-set \
    --stack-name "$STACK_NAME" \
    --change-set-name "$CHANGESET_NAME" \
    --region us-east-1

echo ""
echo "=========================================="
echo "CHANGES SUMMARY"
echo "=========================================="

# Display a simplified view of changes
aws cloudformation describe-change-set \
    --stack-name "$STACK_NAME" \
    --change-set-name "$CHANGESET_NAME" \
    --region us-east-1 \
    --query 'Changes[*].[ResourceChange.Action,ResourceChange.LogicalResourceId,ResourceChange.ResourceType,ResourceChange.Replacement]' \
    --output table

echo ""
echo "=========================================="
echo "NEXT STEPS"
echo "=========================================="
echo ""
echo "To execute this changeset, run:"
echo "  aws cloudformation execute-change-set --stack-name $STACK_NAME --change-set-name $CHANGESET_NAME --region us-east-1"
echo ""
echo "To delete this changeset without executing, run:"
echo "  aws cloudformation delete-change-set --stack-name $STACK_NAME --change-set-name $CHANGESET_NAME --region us-east-1"
echo ""
echo "To view this changeset again, run:"
echo "  aws cloudformation describe-change-set --stack-name $STACK_NAME --change-set-name $CHANGESET_NAME --region us-east-1"
echo ""

# Ask if user wants to execute the changeset
read -p "Do you want to execute this changeset now? (yes/no): " execute

if [ "$execute" == "yes" ]; then
    echo ""
    echo "Executing changeset..."
    aws cloudformation execute-change-set \
        --stack-name "$STACK_NAME" \
        --change-set-name "$CHANGESET_NAME" \
        --region us-east-1
    
    if [ $? -eq 0 ]; then
        echo "Changeset execution initiated successfully!"
        echo ""
        echo "You can monitor the stack update progress with:"
        echo "  aws cloudformation describe-stack-events --stack-name $STACK_NAME --region us-east-1"
        echo ""
        echo "Or watch the stack status with:"
        echo "  watch 'aws cloudformation describe-stacks --stack-name $STACK_NAME --region us-east-1 --query \"Stacks[0].StackStatus\" --output text'"
    else
        echo "Failed to execute changeset. Please check the error message above."
        exit 1
    fi
else
    echo "Changeset execution skipped. The changeset has been saved and can be executed later."
fi

