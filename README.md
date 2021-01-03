This is a Packer project to generate Windows Evaluation images to use on test/dev/hack/IR_labs and the idea is to have these images as a target for configuration manager solutions like Ansible to configure, for this I have another project I been working that I plan to share after this post.

The current coverage for hypervisors/clouds is the following:act

| Hypervisor / Cloud | Status |
| ----------- | ----------- |
| QEMU | Completed |
| VMWare vSphere| Completed |
| Amazon Web Service | Completed |
| Google Cloud Platform| Completed |
| Azure| Pending |

_Just as a reminder, the QEMU image is compatible with environments like GNS3 or EVE-NG as both uses QEMU under the hood._

And the coverage for Windows versions is the following:

| Edition | Build | Status |
| ---------|-- | ----------- |
| Windows 10 Enterprise | 1803 |Completed |
| Windows 10 Enterprise | 1903 |Completed |
| Windows 10 Enterprise | 1909 |Completed |
| Windows 2016 Datacenter | 14393 |Completed |
| Windows 2019 Datacenter | 17763 |Completed |


The code has been tested on this environment:

- __OS:__ Ubuntu 18.04.5 LTS
- __Packer:__ 1.6.2
- __GOVC:__ 0.23.0
- __GSUtil:__ 4.53
- __VMWare vSphere:__ 7.0.1
- __QEMU:__ 2.11

__Note: when building on VMWare vSphere, packer expects that the VM can receive an IP via DHCP.__


### Template structure 

To avoid creating a definition for each edition and build, I used a  nested variables approach, which is like a modular way to work with Packer. A base template includes two builders, one for VMware and the other for QEMU; it also consists of a standard set of provisioners and a set of post-processors to convert the resulting image into a format compatible with the adobe specified hypervisors/clouds. I'm trying to track the sources I used to build this, but there are just too many, and also, some of them were obsolete, and I had to make significant changes.

The main template file is: 

```
windows-base.json
```

To make the template work, it needs a set of variables, the first ones we need to pass is what ISO file is going to be used to build the windows instance. The files that includes this information are the following:

```
windows-10-1803-iso.json
windows-10-1903-iso.json
windows-10-1909-iso.json
windows-2016-iso.json
windows-2019-iso.json
```

The idea is to make this template future-proof, and the structure of the variables can be adapted to cover another version of windows:

```
{
    "name": "windows-10-1803",
    "iso_url": "https://software-download.microsoft.com/download/pr/17134.1.180410-1804.rs4_release_CLIENTENTERPRISEEVAL_OEMRET_x64FRE_en-us.iso",
    "iso_checksum_type": "sha1",
    "iso_checksum": "a4ea45ec1282e85fc84af49acf7a8d649c31ac5c"
}
```

Just replace the content of the variables as needed.

Now, depending on the hypervisor to use there are a set of common variables included in the following files:

```
windows-10-qemu-vars.json
windows-10-vsphere-vars.json
windows-2016-qemu-vars.json
windows-2016-vsphere-vars.json
windows-2019-dc-qemu-vars.json
windows-2019-vsphere-vars.json
```

Again, this can be adapted to match other resources to allocate CPU, RAM, and disk sizes, and to specify the content of the floppy drive to use during the unattended installation.

```
{
"disk_size": "81920",
"memory": "8192",
"cpus": "8",
"floppy_files_list" : "floppy/drivers/virtio/*,floppy/ConfigureRemotingForAnsible.ps1,autounattend/windows_2019/qemu/autounattend.xml"
}
```
As you can see inside the files depending on the version and the hypervisor there is a different autounattend.xml file, these autounattend.xml files includes among other settings the credentials to set during the installation.

The list of files included are:

```
./autounattend/windows_10/vsphere/autounattend.xml
./autounattend/windows_10/qemu/autounattend.xml
./autounattend/windows_2016/vsphere/autounattend.xml
./autounattend/windows_2016/qemu/autounattend.xml
./autounattend/windows_2019/vsphere/autounattend.xml
./autounattend/windows_2019/qemu/autounattend.xml
```

The credentials can be changed if needed in the following section of those autounattend.xml files:

```
<UserAccounts>
    <AdministratorPassword>
        <Value>40Net123#</Value>
        <PlainText>true</PlainText>
    </AdministratorPassword>
    <LocalAccounts>
        <LocalAccount wcm:action="add">
            <Password>
            <Value>40Net123#</Value>
            <PlainText>true</PlainText>
            </Password>
            <Group>administrators</Group>
            <DisplayName>Lab Admin</DisplayName>
            <Name>labadmin</Name>
            <Description>Lab Admin</Description>
        </LocalAccount>
    </LocalAccounts>
</UserAccounts>
```
```
<AutoLogon>
    <Password>
        <Value>40Net123#</Value>
        <PlainText>true</PlainText>
    </Password>
    <Enabled>true</Enabled>
    <Username>labadmin</Username>
</AutoLogon>
```

The variable files that includes the credentials to match what is defined in the autounattend.xml file, is: 


- packer-creds.json

```
{
    "packer_user": "labadmin",
    "packer_pass": "40Net123#"
}
```

Depending of the environment to use for build the image or to where to export the resulting template there is a group of credentials that we need to defined, the templates are defined as:


- vsphere-creds-template.json
```
{
    "vsphere-server": "",
    "vsphere-user": "",
    "vsphere-password": "",
    "vsphere-datacenter": "",
    "vsphere-cluster": "" ,
    "vsphere-network": "" ,
    "vsphere-datastore": "",
    "vsphere-folder": ""
}
```

- aws-creds-template.json
```
{
    "aws_secret_key": "",
    "aws_access_key": ""
}
```


The next set of variables, are related to accommodate the output format to each hypervisor/cloud, those files are:

- kvm-vars.json
```
{
    "compress": "true",
    "disk_format": "qcow2"
}
```

- gcp-vars.json
```
{
    "compress": "false",
    "disk_format": "raw",
    "gcs_bucket" : "packer_images"
}
```

- aws-vars.json
```
{
    "aws_region": "us-east-1",
    "aws_s3_bucket_name": "packer-windows-images",
    "enable_aws_tool" : "true"
}
```
### Mixing all together 

There is a set of parameters that are passed during the execution, those are:

- __-only:__ This helps to specify which builder we want to use, and it also enables some specific provisioners and post-processors.
- __-except:__ This helps to ignore some specific provisioners and post-processors to accommodate the target environment.
- __-var tag=:__ This allows us to append a custom name to the image to create.
- __-var vsphere-maketemplate=true/false__: This only applies when building an image for vSphere or AWS, and specify if we want to convert the resulting image into a VM Template.

After understand the set of variables needed, we can proceed to the execution of Packer, so it can take care of the whole building process

- _Windows 10 Enterprise Build 1903 on QEMU (using a local environment):_

```
packer build -only=qemu -var-file=windows-10-1903-iso.json -var-file=windows-10-qemu-vars.json -var-file=packer-creds.json -var-file=kvm-vars.json -except=gcp -var tag=golden windows-base.json
```

This is an output example I recorded as reference: 

<script id="asciicast-wXJTCFOSpVNa8ssrd02AQdUqS" src="https://asciinema.org/a/wXJTCFOSpVNa8ssrd02AQdUqS.js" async data-speed="30"></script>

Now lets use a vSphere environment, and for this we are going to change some of the variables files as shown in the following example:

- _Windows 10 Enterprise Build 1903 on VMWare vSphere:_

```
packer build -only=vsphere-iso -except=aws,pre-ovf-aws,export-ovf -var-file=windows-10-1903-iso.json -var-file=windows-10-vsphere-vars.json -var-file=packer-creds.json -var-file=vsphere-creds.json  -var tag=golden -var vsphere-maketemplate=true windows-base.json
```

This by default is going to export the resulting template as OVF, if we want to avoid that, we need add the following parameter to the "-except" section: "export-ovf". The resulting line it would be:

```
packer build -only=vsphere-iso -except=aws,pre-ovf-aws -var-file=windows-10-1903-iso.json -var-file=windows-10-vsphere-vars.json -var-file=packer-creds.json -var-file=vsphere-creds.json  -var tag=golden -var vsphere-maketemplate=true windows-base.json

```

Now, if we want to upload the resulting image built with QEMU to GCP, we neet to first install and configure gsutil, you can follow this guide: https://cloud.google.com/storage/docs/gsutil_install, then we need to create a Cloud Storage Bucket and then we can use the command: ```gsutil config``` to set the configuration. The Packer template already have the commands needed to upload and register the image to make it ready to launch new instances on Google Cloud using the resulting image.


- _Windows 10 Enterprise Build 1903 on QEMU (and upload it to Google Cloud Platform):_

```
packer build -only=qemu -var-file=windows-10-1903-iso.json -var-file=windows-10-qemu-vars.json -var-file=packer-creds.json -var-file=gcp-vars.json -except=fix-output-qcow2 -var tag=take15 windows-base.json
```

Then, if we want to build a Windows 2019 image, we can use the following command where you will notice that only a couple of variables changed, the same logic explained with the other commands applies:


- _Windows 2019 Server Datacenter on QEMU (using a local environment):_

```
packer build -only=qemu -var-file=windows-2019-iso.json -var-file=windows-2019-dc-qemu-vars.json -var-file=packer-creds.json -var-file=kvm-vars.json -except=gcp -var tag=golden windows-base.json
```

For AWS there are a few previous steps needed:

1. Configure the AWS command-line utility, you can follow [this guide](https://docs.aws.amazon.com/polly/latest/dg/setup-aws-cli.html)
2. Create an S3 bucket, you can follow [this guide](https://docs.aws.amazon.com/AmazonS3/latest/user-guide/create-bucket.html)
3. There is a folder named "aws", inside you will find two files, one of them is: "role-policy-tpl.json", you can make a local copy of that file, then locate and change the text: ```REPLACETHISWITHYOURBUCKET```
4. Execute the following commands (replace the path and the role-policy file name as needed):

```
aws iam create-role --role-name vmimport --assume-role-policy-document file:///path/to/trust-policy.json
aws iam put-role-policy --role-name vmimport --policy-name vmimport --policy-document file:///path/to/role-policy-newfile.json
```
5. Make a copy of the file  ```aws-creds-template.json``` to ```aws-creds.json``` and define your own AWS Keys, then execute:

```
packer build -only=vsphere-iso -var-file=windows-10-1903-iso.json -var-file=windows-10-vsphere-vars.json -var-file=packer-creds.json -var-file=vsphere-creds.json -var-file=aws-creds.json -var-file=aws-vars.json  -var vsphere-maketemplate=false -var tag=golden windows-base.json
```

This will build an AWS ready AMI and will upload it using the included Packer plugin into your AWS account, after the process finish you will be able to deploy the image from your custom AMI images into EC2.
