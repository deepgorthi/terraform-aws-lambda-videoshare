provider "aws" {
    region = var.aws_region
}

resource "random_id" "vb_upload" {
    byte_length = 2
}

resource "aws_s3_bucket" "vb_upload" {
    bucket  = "svs-deep-upload-${random_id.vb_upload.dec}"
    acl = "private"
    force_destroy = true

    tags = {
        Name        = "Video bucket"
        Environment = "Dev"
    }
}

resource "aws_s3_bucket" "vb_trans" {
    bucket  = "svs-deep-transcoded-${random_id.vb_upload.dec}"
    acl = "private"
    force_destroy = true

    tags = {
        Name        = "Video bucket transcoded"
        Environment = "Dev"
    }
}