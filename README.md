# AWS lambda api-gateway go terraform

Golang lambda function with API-Gateway on AWS provision with Terraform.

## Setting credentials

* Generate IAM user in IAM console
* Generate access keys in IAM > Users > [your username] and download it
* Generate credentials file using `cp credentials.example credentials`
* Paste downloaded credentials from AWS to `credentials` file in project root

## Build binaries

```sh
go mod tidy
GOOS=linux GOARCH=amd64 go build -o bin/main
```

## Terraform

```sh
terraform init
terraform plan
terraform apply -auto-approve
terraform destroy -auto-approve
```
