# Terraform for infrastructure provisioning

We use Terraform instead of AWS SAM or CDK to provision the stack (Lambda, API Gateway, DynamoDB, S3, CloudFront). The project owner has an existing Terraform workflow and prefers cloud-agnostic tooling, even though SAM would be the more natural fit for a purely serverless AWS stack.

## Considered Options

**AWS SAM** — purpose-built for serverless, less verbose, includes `sam local` for local Lambda invocation. Rejected because the team is more familiar with Terraform and wants consistent tooling across projects.

**AWS CDK** — more expressive than SAM for complex infra, but adds a TypeScript/Python compilation step and more boilerplate for a stack this simple.
