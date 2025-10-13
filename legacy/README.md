# Legacy Infrastructure Artifacts

This directory archives the earlier multi-stack infrastructure (networking, servers-and-security-groups, storage) retained for historical reference after migration to the simplified `infrastructure/` CloudFormation templates.

Contents (each largely superseded):
- networking/ : Original VPC, subnets, routes, bastion-oriented templates
- servers-and-security-groups/ : Older ASG + Bastion + security group definitions
- storage/ : Prior database & S3 templates

The active deployment path now uses:
```
/infrastructure/01-network.yml
/infrastructure/02-database.yml
/infrastructure/03-backend.yml
/infrastructure/04-frontend.yml
/infrastructure/main.yml
```

These legacy templates are not maintained. Prefer the new modular stack. You may safely delete this entire `legacy/` folder if you no longer need the reference (Git history also preserves them).
