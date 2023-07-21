# Antipode @ TrainTicket

In this repo you will find found how Antipode fixes one of the inconsistencies found on TrainTicket benchmark.

Developed as a testbed for replicating industrial faults, the TrainTicket benchmark is a microservice-based application that provides typical ticket booking functionalities, such as ticket reservation and payment. It is implemented in Java and it consists of more than 40 services including web servers, datastores and queues.

We focus on the F1 error (details on Xiang et al paper) that occurs when a user cancels a ticket.
This operation is split into two tasks:
  (a) changing the status of the ticket to be cancelled, and
  (b) refunding the ticket price to the client.

These events are performed by different services. A violation happens when the refund (b) is delayed, which results in the customer not seeing the refunded amount right away.
This scenario is identified by the fault analysis survey performed by the benchmark authors: " using asynchronous tasks within a request might result in events being processed in a different order, which might lead to incorrect application behavior".

Antipode was added by placing a `barrier` before returning the cancellation output to the user.


## Prerequisites

You need to install the following dependencies before runnning:
- Python 3.7+
- The requisites for our `maestro` script. Simply run `pip install -r requirements.txt`
- Docker
- Pull submodules: `git submodule update --init --recursive`

Prerequesites for **Local** deployment:
- Docker Swarm

Prerequesites for **GCP** deployment:
- Google Cloud Platform account
- Create a credentials JSON file ([instructions here](https://developers.google.com/workspace/guides/create-credentials)) and place the generated JSON file in `gcp` folder and name it `credentials.json`
- You might need to [increase your Compute Engine quotas](https://console.cloud.google.com/iam-admin/quotas).

Optional dependencies:
- `tmux` and (`xpanes`)[https://github.com/greymd/tmux-xpanes] for `ssh` command to connect to multiple ssh connections

## Usage
All the deployment is controlled by our `./maestro` script. Type `./maestro -h` to look into all the commands and option, and also each command comes with its own help, e.g. `./maestro run -h`.

### Local Deployment

This environment is mainly used for development and debugging.

*In preparation*

### GCP Deploymnet
Make sure you have created a Google Cloud Platform (GCP) account and have setup a new project.
Go to the `config.yml` file and add your GCP project and user information, for example:
```yml
gcp:
  project_id: antipode
  default_ssh_user: jfloff
```

Then run *maestro* to build and deploy the GCP instances:
```zsh
./maestro --gcp build
./maestro --gcp deploy -config CONFIG_FILE -clients NUM_CLIENTS
```
You can either build your own deployment configuration file, or you one already existing.
For instance, for SOSP'23 plots you should use the `configs/sosp23.yml` config and `1` as number of clients.

After deploy is done you can start the TrainTicket services with:
```zsh
./maestro --gcp run -antipode
```
In order to run the original TrainTicket application remove the `-antipode` parameter.

With our services started we run the workload:
```zsh
./maestro --gcp wkld -d DURATION_SEC -c NUM CLIENTS -t NUM_THREADS
```
For instance, we can the workload for 300 seconds (`300`), and with `1` client (same as the deploy command) with `12` concurrent threads.
At the end the `wkld` command will make available in the `gather` folder the evaluation results. The gather folder is key for plotting after (see ahead).


At the end, you can clean your experiment and destroy your GCP instance with:
```zsh
./maestro --gcp clean -strong
```
In order to keep your GCP instances and just undeploy undeploy the TrainTicket application, remove the `-strong` parameter.


Although `maestro` run a single deployment end-to-end, in order to run all the necessary workloads for plots you need to repeat these steps for several different combinations.
To ease that process we provide `maestrina`, a convenience script that executes all combinations of workloads to plot after. In order to change the combinations just edit the code get your own combinations in place. There might be instances where `maestrina` is not able to run a specific endpoint, and in those scenarios you might need to rerun ou run `maestro` individually -- which is always the safest method.


There are other commands available (for details do `-h`), namely:
- `./maestro --gcp seed` that seeds targeted datastores with random data. This does not need to run everytime because we already generated a seed and restore it before running the workload.
- `./maestro --gcp info` that has multiple options from links to admin panels, logs and others
- `./maestro --gcp ssh` which is able to connect to multiple GCP instance via ssh


## Plots

The first step to build plots is making sure that you have all the datapoints first.
After that you need to set those datapoints into a *plot config file*, similar to the one provided at `plots/configs/sample.yml`.

With a configuration set with your datapoint, you simply run:
```zsh
./plot CONFIG --plots throughput_latency_with_consistency_window
```
To generate a throughput/latency plot in combination with our consistency window metric.
There is also only an individual throughput/latency plot with the key `throughput_latency`. For more information type `./plot -h`


## Paper References

João Loff, Daniel Porto, João Garcia, Jonathan Mace, Rodrigo Rodrigues  
Antipode: Enforcing Cross-Service Causal Consistency in Distributed Applications  
To appear.  
[Download]()


Xiang Zhou, Xin Peng, Tao Xie, Jun Sun, Chao Ji, Wenhai Li, and Dan Ding.  
Fault Analysis and Debugging of Microservice Systems: Industrial Survey, Benchmark System, and Empirical Study.  
IEEE Transactions on Software Engineering 2021  
[Download](https://ieeexplore.ieee.org/ielaam/32/9352984/8580420-aam.pdf)
