tf-aws-windows-auto-packer
==========================

This module is for creating packer images on an EC2 Windows instance. 

It is triggered by copying a packer json file to the auto-packer s3 bucket. This triggers a lambda function that launches an ec2 instance bootstrapped to run the relevant packer job.

There a 3 benefits of this using this module to create your packer images:-

1) The packer run does not tie up your machine during the packer run

2) Simultaneous packer runs can occur at once 

3) A packer run can run longer than the 1hour restriction that we encounter with 'assumed' access

Once a run has completed the 'runner' instance write that pcker output to the log folder in the auto-packer s3 bucket.


Prerequisites
-------------

1)The s3 bucket must contain a zip of the packer\include folder.

2)The above zip file must have the \include folder inside it

3)Any paths referenced in the json packer files must be reference from the parent of the include folder

4)The subnet defined in env_subnet_id must be able to route to the internet

Usage
-----

Declare a module in your Terraform file, for example:



module "auto-packer" {

  source   = "../modules/tf-aws-auto-packer"
  
  envname  = "${var.envname}"
  
  envtype  = "${var.envtype}"
  
  customer = "ao"

  env_image_id      = "ami-f4bc4f8d"
  
  env_instance_type = "t2.nano"
  
  env_keyname       = "${var.key_name}"
  
  env_subnet_id     = "${element(module.vpc.private, 0)}"
  
  vpc_id            = "${module.vpc.vpc_id}"


}


Variables
---------

- `customer`           - name of customer
- `envtype`            - name of environment type
- `envname`            - name of environment

- `env_image_id`       - id of windows ami for runner instance
- `env_instance_type`  - name of ec2 instance_type for runner instance
- `env_keyname`        - name of ec2 keypair for runner instance
- `env_subnet_id`      - id of subnet for runner instance
- `vpc_id`             - id of vpc

