# LinkBox Infrastructure Diagram (Mermaid)

```mermaid
graph TD
  subgraph Client["Client"]
    U[Browser]
  end

  subgraph CloudFront["CloudFront Distribution"]
    CF["Edge Cache"]
  end

  subgraph S3Frontend["S3 Static Site Bucket"]
    S3FE["index.html + assets"]
  end

  subgraph VPC[VPC]
    subgraph PublicSubnets[Public Subnets]
      ALB[Application Load Balancer]
    end
    subgraph PrivateSubnets[Private Subnets]
      ASG[EC2 ASG FastAPI]
      RDS[(PostgreSQL)]
    end
  end

  subgraph S3Uploads[S3 Uploads Bucket]
    S3UP[(uploads/ID-file)]
  end

  U -->|"HTTPS"| CF
  CF -->|"GET / (static)"| S3FE
  CF -->|"/api/*"| ALB
  ALB --> ASG
  ASG -->|"Presign POST"| S3UP
  U -->|"Browser direct POST (presigned)"| S3UP
  ASG -->|"Metadata (SQL)"| RDS
  CF -->|"GET /files/{id} (optional redirect)"| ALB
```

Legend:
- Presigned upload: Browser POSTs directly to S3 using form fields from backend.
- ASG container only touches metadata, not file payload.
- CloudFront provides two behaviors: static (default) & /api/* (ALB origin).
