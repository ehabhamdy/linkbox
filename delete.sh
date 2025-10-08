#!/bin/bash

if [ $# -ne 1 ]; then
    echo "Usage: $0 <stack-name>"
    exit 1
fi

STACK_NAME="$1"

echo "WARNING: This will permanently delete the CloudFormation stack: $STACK_NAME"
echo "This action cannot be undone!"
read -p "Are you sure you want to continue? (yes/no): " confirmation

if [ "$confirmation" != "yes" ]; then
    echo "Stack deletion cancelled."
    exit 0
fi

echo "Deleting CloudFormation stack: $STACK_NAME"

aws cloudformation delete-stack \
    --stack-name "$STACK_NAME"

if [ $? -eq 0 ]; then
    echo "Stack deletion initiated successfully!"
    echo "You can monitor the progress with:"
    echo "aws cloudformation describe-stacks --stack-name $STACK_NAME"
    echo "Note: The stack will show DELETE_IN_PROGRESS status until fully deleted."
else
    echo "Failed to delete stack. Please check the error message above."
    exit 1
fi