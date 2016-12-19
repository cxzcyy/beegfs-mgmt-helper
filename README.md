# beegfs-mgmt-helper
BeeGFS Administrator's Helper - Easily manage and monitor the Famous BeeGFS (Parallel HPC FS)



**Pre-Word**

BeeGFS is so far he most scalble and the fastest Distributed Network Attached File System, but it lacks handy administrative console interface. 
I have created a script to have an easy way to monitor and administer the BeeGFS system setup. The script is continuously updated with new functions...

You are free to use the script in your Production setup, and if any ideas arise, please feel free to open an Issue, or Fork the repo, that I can enhance the script. 

**Requirements**
* Have BeeGFS system set up
* Run on the Management Host with `beegfs-utils` package installed
* To be able to use all of the functions of the script, it is advised to execute the script under `root user` or with `sudo` command

**Change initial settings**

Under `#### EDIT VARIABLES BELLOW, TO FIT YOUR ENVIRONMENT ####` change variables' values to match your BeeGFS environment.

**Supported Systems**

Any Linux Distribution with latest BeeGFS build
* Developed, and Deployed under Ubuntu 16.04


*Repository Maintenance*
Since Dec 15, 2016 I am not to maintain the repository. I have very bad experience with the BeeGFS. The BeeGFS corrupted hundreds of files, so I ended up abandoning it and switching over to GlusterFS.
