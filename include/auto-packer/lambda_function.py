import boto3
import os

ec2 = boto3.resource('ec2')

def lambda_handler(event, context):
    file = event['Records'][0]['s3']['object']['key']
    build = file.split(".")[0]
    user_data="""
    <powershell>
    stop-process -Name packer -Force
    Remove-Item -Path c:\packer -Force
    net user administrator Password01
    $AllProtocols = [System.Net.SecurityProtocolType]'Ssl3,Tls,Tls11,Tls12'
    [System.Net.ServicePointManager]::SecurityProtocol = $AllProtocols
    $url = "https://releases.hashicorp.com/packer/1.0.4/packer_1.0.4_windows_amd64.zip"
    $output = "c:\packer.zip"
    Invoke-WebRequest -Uri $url -OutFile $output
    Expand-Archive -Path C:\packer.zip -DestinationPath c:\packer
    $local_installers = "c:\packer"
    $installers_bucket = "%(2)s"
    $s3key = "include.zip"
    $installer = "c:\packer\include.zip"
    Copy-S3Object -BucketName $installers_bucket -Key $s3key -LocalFile $installer
    Expand-Archive -Path C:\packer\include.zip -DestinationPath C:\packer
    $s3key = "%(1)s"
    $installer = "c:/packer/%(1)s"
    Copy-S3Object -BucketName $installers_bucket -Key $s3key -LocalFile $installer
    cd $local_installers
    ./packer.exe build $s3key | Tee-Object -FilePath C:\packer\log.txt
    $log=$s3key.Split(".")[0] + "-"+(get-date -f "yyyy-MM-dd-HH-mm") + ".log"
    Write-S3Object -BucketName ao-prod-auto-packer -File c:\packer\log.txt -Key log\$log
    Stop-EC2Instance -Terminate -Force 
    $instance=(Invoke-RestMethod -Method Get -Uri http://169.254.169.254/latest/meta-data/instance-id).Trim()
    Remove-EC2Instance-InstanceId $instance -Force
    </powershell>
    """ % {"1" : file, "2" : os.environ['env_s3_bucket'] }
    
    instances = ec2.create_instances(
    ImageId=os.environ['env_image_id'], 
    MinCount=1,
    MaxCount=1,
    InstanceType=os.environ['env_instance_type'],
    KeyName=os.environ['env_keyname'],
    SubnetId=os.environ['env_subnet_id'],
    SecurityGroupIds=[os.environ['env_security_group']],
    UserData=user_data,
    IamInstanceProfile={'Arn':os.environ['env_instance_profile_arn']},
    TagSpecifications=[
        {
            'ResourceType': 'instance',
            'Tags': [
                {
                    'Key': 'Name',
                    'Value': 'Packer Runner - ' + build
                },
            ]
        },
    ]
    )