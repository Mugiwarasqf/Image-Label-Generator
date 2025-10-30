variable "project_name" {
  type    = string
  default = "rekognition-labeler"
}

variable "aws_region" {
  type    = string
  default = "eu-west-2"   # London region
}

variable "bucket_name" {
  type    = string
  default = "numenhaus-rekognition-uploads"  # must be globally unique
}

variable "table_name" {
  type    = string
  default = "image_labels"
}
