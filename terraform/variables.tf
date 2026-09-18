variable "region" {
  description = "One commercial AWS Region. Reference design and prices use us-east-1."
  type        = string
  default     = "us-east-1"
  validation {
    condition     = can(regex("^(us|eu|ap|ca|sa|me|af|il|mx)-(central|north|south|east|west|northeast|northwest|southeast|southwest)-[1-9]$", var.region))
    error_message = "Use a commercial AWS Region, for example us-east-1."
  }
}

variable "expected_account_id" {
  description = "Required account guardrail: the 12-digit AWS account authorized for this lab."
  type        = string
  validation {
    condition     = can(regex("^[0-9]{12}$", var.expected_account_id))
    error_message = "Set your 12-digit sandbox account ID."
  }
}

variable "lab_id" {
  description = "Unique lab prefix in this account/Region; do not change after deployment."
  type        = string
  default     = "aws-netlab"
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,19}$", var.lab_id))
    error_message = "Use 3-20 lowercase letters, numbers or hyphens, starting with a letter."
  }
}

variable "owner" {
  description = "Non-sensitive owner label for cost allocation."
  type        = string
  default     = "student"
  validation {
    condition     = length(var.owner) > 0 && length(var.owner) <= 64
    error_message = "Owner must contain 1-64 characters."
  }
}

variable "availability_zone" {
  description = "Optional standard AZ in the selected Region. Both VPCs use the same AZ."
  type        = string
  default     = null
  validation {
    condition     = var.availability_zone == null ? true : can(regex("^[a-z]{2}-[a-z]+-[1-9][a-z]$", var.availability_zone))
    error_message = "Use a standard AZ name such as us-east-1a, or null."
  }
}

variable "ami_id" {
  description = "Optional pinned Amazon Linux 2023 x86_64 standard AMI. Scripts pin the public SSM parameter on first deployment."
  type        = string
  default     = null
  validation {
    condition     = var.ami_id == null ? true : can(regex("^ami-[0-9a-f]{17}$", var.ami_id))
    error_message = "Use a full AMI ID or null."
  }
}

variable "instance_type" {
  description = "Small x86_64 burstable instance; standard credits prevent surplus-credit charges."
  type        = string
  default     = "t3.micro"
  validation {
    condition     = contains(["t3.micro", "t3.small"], var.instance_type)
    error_message = "Choose t3.micro or t3.small."
  }
}

variable "log_retention_days" {
  description = "CloudWatch Flow Log retention. Logs are destroyed with the lab."
  type        = number
  default     = 3
  validation {
    condition     = contains([1, 3, 5, 7, 14, 30], var.log_retention_days)
    error_message = "Choose 1, 3, 5, 7, 14 or 30 days."
  }
}

variable "scenario" {
  description = "Exactly one controlled fault. Scripts require healthy baseline before changing from baseline."
  type        = string
  default     = "baseline"
  validation {
    condition     = contains(["baseline", "routing", "security-group", "nacl", "dns", "s3-policy"], var.scenario)
    error_message = "Unknown scenario. See docs/scenarios."
  }
}
