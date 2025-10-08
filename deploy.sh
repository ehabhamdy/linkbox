#!/bin/bash

if [ $# -ne 3 ]; then
    echo "Usage: $0 <stack-name> <template-file> <parameter-file>"
    exit 1
fi

STACK_NAME="$1"
TEMPLATE_FILE="$2"
PARAMETER_FILE="$3"

echo "Creating CloudFormation stack: $STACK_NAME"
echo "Using template: $TEMPLATE_FILE"
echo "Using parameter file: $PARAMETER_FILE"

aws cloudformation deploy \
    --stack-name "$STACK_NAME" \
    --template-file "$TEMPLATE_FILE" \
    --parameter-overrides file://"$PARAMETER_FILE" \
    --region us-east-1