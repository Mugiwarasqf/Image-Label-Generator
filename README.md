# AWS Rekognition Image Labeler

Automatically generates labels for images uploaded to S3 using AWS Rekognition and stores results in DynamoDB.

## Architecture

- **S3 Bucket**: Receives image uploads
- **Lambda Function**: Triggered by S3 events, calls Rekognition API
- **DynamoDB Table**: Stores image labels and metadata
- **AWS Rekognition**: Analyzes images and detects labels

## Prerequisites

- AWS CLI configured with appropriate credentials
- Terraform >= 1.6.0
- Python 3.11

## Setup

1. **Configure variables**:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```
   Edit `terraform.tfvars` and set a globally unique `bucket_name`.

2. **Deploy infrastructure**:
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

## Usage

1. Upload an image to the S3 bucket
2. Lambda automatically processes the image
3. Labels are stored in DynamoDB with confidence scores

## DynamoDB Schema

```json
{
  "image_key": "photo.jpg",
  "labels": [
    {"name": "Person", "confidence": "99.85"},
    {"name": "Human", "confidence": "99.85"}
  ],
  "processed_at": "2024-01-01T12:00:00Z"
}
```

## Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `project_name` | `rekognition-labeler` | Project identifier |
| `aws_region` | `eu-west-2` | AWS region |
| `bucket_name` | - | S3 bucket name (must be unique) |
| `table_name` | `image_labels` | DynamoDB table name |

## Cleanup

```bash
terraform destroy
```